/**
 * Export Single Bill/Invoice to PDF
 * Matches the web app's invoice format exactly
 */
const PDFDocument = require('pdfkit');

class ExportBillPDF {
  constructor(billRepository, customerRepository, jobRepository) {
    this.billRepository = billRepository;
    this.customerRepository = customerRepository;
    this.jobRepository = jobRepository;
  }

  async execute(billId) {
    if (!billId) throw new Error('Bill ID is required');

    const bill = await this.billRepository.findById(billId);
    if (!bill) throw new Error('Bill not found');

    // Fetch customer details
    let customer = { name: bill.customerId || '-' };
    try {
      if (bill.customerId) {
        const c = await this.customerRepository.findById(bill.customerId);
        if (c) customer = c;
      }
    } catch (_) {}

    // Fetch job details (including pay items)
    let job = {};
    try {
      if (bill.jobId) {
        job = await this.jobRepository.findById(bill.jobId);
        if (job && job.toJSON) job = job.toJSON();
      }
    } catch (_) {}

    return this._generatePDF(bill, customer, job);
  }

  _generatePDF(bill, customer, job) {
    const fmt = (v) =>
      parseFloat(v || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

    const fmtDate = (d) => {
      if (!d) return '-';
      const date = new Date(d);
      if (isNaN(date.getTime())) return '-';
      return date.toLocaleDateString('en-GB');
    };

    const formatCusdecNumber = (value) => {
      const rawValue = (value || '').trim();
      if (!rawValue) return '';
      const cleaned = rawValue.replace(/^i\s*-\s*/i, '').trim();
      return cleaned ? `I-${cleaned}` : '';
    };

    const formatCusdecWithDate = (cusdecNumber, cusdecDate) => {
      const formattedNumber = formatCusdecNumber(cusdecNumber);
      if (!formattedNumber) return '-';
      const formattedDate = fmtDate(cusdecDate);
      return formattedDate && formattedDate !== '-' ? `${formattedNumber} of ${formattedDate}` : formattedNumber;
    };

    const invoiceNumber = bill.invoiceNumber || bill.billId;
    const advancePayment = parseFloat(bill.advancePayment || job.advancePayment || 0);
    const grossTotal = parseFloat(bill.grossTotal || bill.billingAmount || bill.amount || 0);
    const netTotal = grossTotal - advancePayment;
    const advancePaymentDate = bill.advancePaymentDate || job.advancePaymentDate || job.paymentMadeDate;

    // Build address string
    let addressLine = '';
    if (customer.addressNumber || customer.addressStreet1 || customer.addressCity) {
      const parts = [
        customer.addressNumber,
        customer.addressStreet1,
        customer.addressStreet2,
        customer.addressDistrict,
        customer.addressCity,
        customer.addressCountry || 'Sri Lanka'
      ].filter(Boolean);
      addressLine = parts.join(', ');
    }

    // Parse pay items
    let payItems = [];
    if (job.payItems) {
      if (typeof job.payItems === 'string') {
        try { payItems = JSON.parse(job.payItems); } catch (_) {}
      } else if (Array.isArray(job.payItems)) {
        payItems = job.payItems;
      }
    }
    // Also check officePayItems
    if (payItems.length === 0 && job.officePayItems && Array.isArray(job.officePayItems)) {
      payItems = job.officePayItems;
    }

    const isVehicleCategory = (cat) =>
      cat === 'Vehicle - Personal' || cat === 'Vehicle - Company' || cat === 'Vehicle';

    // ── Build PDF ──────────────────────────────────────────────────────────
    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const chunks = [];
      doc.on('data', c => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const W = doc.page.width;
      const M = 40;
      const CW = W - M * 2;

      const PRIMARY = '#1a3e9a';
      const ACCENT = '#2f6bd6';
      const MUTED = '#3f4f77';
      const SOFT_BG = '#e8f0ff';

      let y = M;

      // ── Page Header with company info ──────────────────────────────────
      // Header background
      doc.rect(M, y, CW, 60).fill(SOFT_BG);
      doc.rect(M, y, CW, 60).strokeColor(PRIMARY).lineWidth(1.5).stroke();

      // Company name centered
      doc.fillColor(PRIMARY).fontSize(14).font('Helvetica-Bold')
        .text('SUPER SHINE CARGO SERVICES', M, y + 10, { width: CW, align: 'center' });
      doc.fillColor(MUTED).fontSize(8).font('Helvetica')
        .text('CLEARING & FORWARDING AGENTS', M, y + 28, { width: CW, align: 'center' });
      doc.text('No 04, Marine Drive, Colombo 01, Sri Lanka', M, y + 39, { width: CW, align: 'center' });
      doc.text('Tel: +94 11 244 5566  |  Email: info@supershinecargo.com', M, y + 49, { width: CW, align: 'center' });

      y += 70;

      // ── Invoice Number & Date ──────────────────────────────────────────
      doc.fillColor('#111').fontSize(10).font('Helvetica-Bold')
        .text(`INV No: ${invoiceNumber}`, M, y);
      doc.fontSize(9).font('Helvetica')
        .text(`Date: ${fmtDate(bill.invoiceDate || bill.billDate || bill.createdDate)}`, M, y + 14);

      y += 34;

      // ── Recipient ──────────────────────────────────────────────────────
      doc.fillColor('#111').fontSize(9).font('Helvetica')
        .text('The Director,', M, y);
      y += 13;
      doc.fontSize(10).font('Helvetica-Bold')
        .text(customer.name || customer.customerId || '-', M, y);
      y += 14;
      if (addressLine) {
        doc.fontSize(9).font('Helvetica')
          .text(addressLine, M, y, { width: CW });
        y += 13;
      }

      y += 10;

      // ── Details Section ────────────────────────────────────────────────
      doc.moveTo(M, y).lineTo(M + CW, y).strokeColor(PRIMARY).lineWidth(1.5).stroke();
      y += 8;

      const drawDetail = (label, value) => {
        doc.fillColor(PRIMARY).fontSize(9).font('Helvetica-Bold')
          .text(label, M, y, { width: 155, continued: false });
        doc.fillColor('#111').fontSize(9).font('Helvetica')
          .text(`: ${value || '-'}`, M + 155, y);
        y += 15;
      };

      drawDetail('Cusdec No', formatCusdecWithDate(job.cusdecNumber, job.cusdecDate));
      drawDetail('Exporter', job.exporter);
      drawDetail('TT / LC / DA / DP / NFE No', job.lcNumber);
      drawDetail('Container No', job.containerNumber);
      drawDetail('Shipment Category', job.shipmentCategory);
      if (isVehicleCategory(job.shipmentCategory)) {
        drawDetail('Chassis No', job.chassisNumber);
      }

      doc.moveTo(M, y).lineTo(M + CW, y).strokeColor(PRIMARY).lineWidth(1).stroke();
      y += 10;

      // ── Pay Items Table ────────────────────────────────────────────────
      const tableLeft = M;
      const colId = 70;
      const colDesc = CW - colId - 100;
      const colAmt = 100;
      const rowHeight = 18;

      // Table header
      doc.rect(tableLeft, y, CW, rowHeight).fill(SOFT_BG);
      doc.rect(tableLeft, y, CW, rowHeight).strokeColor(PRIMARY).lineWidth(0.5).stroke();

      doc.fillColor(PRIMARY).fontSize(8).font('Helvetica-Bold');
      doc.text('ID', tableLeft + 4, y + 5, { width: colId - 8, align: 'center' });
      doc.text('DESCRIPTION', tableLeft + colId + 4, y + 5, { width: colDesc - 8 });
      doc.text('AMOUNT (LKR)', tableLeft + colId + colDesc + 4, y + 5, { width: colAmt - 8, align: 'right' });

      // Column borders
      doc.moveTo(tableLeft + colId, y).lineTo(tableLeft + colId, y + rowHeight).strokeColor('#cfd7ea').lineWidth(0.5).stroke();
      doc.moveTo(tableLeft + colId + colDesc, y).lineTo(tableLeft + colId + colDesc, y + rowHeight).strokeColor('#cfd7ea').lineWidth(0.5).stroke();

      y += rowHeight;

      // Table rows
      const printableItems = payItems.length > 0 ? payItems : [{ description: 'Service Charges', billingAmount: grossTotal }];

      printableItems.forEach((item, idx) => {
        const description = item.description || item.name || 'Service Charge';
        const amount = parseFloat(item.billingAmount || item.amount || item.actualCost || 0);
        const itemId = item.officePayItemId || item.id || item.payItemId || `PI${String(idx + 1).padStart(3, '0')}`;

        // Row background
        if (idx % 2 === 0) {
          doc.rect(tableLeft, y, CW, rowHeight).fill('white');
        } else {
          doc.rect(tableLeft, y, CW, rowHeight).fill('#f9fafb');
        }

        // Row border
        doc.rect(tableLeft, y, CW, rowHeight).strokeColor('#cfd7ea').lineWidth(0.3).stroke();

        // Column borders
        doc.moveTo(tableLeft + colId, y).lineTo(tableLeft + colId, y + rowHeight).strokeColor('#cfd7ea').lineWidth(0.3).stroke();
        doc.moveTo(tableLeft + colId + colDesc, y).lineTo(tableLeft + colId + colDesc, y + rowHeight).strokeColor('#cfd7ea').lineWidth(0.3).stroke();

        doc.fillColor('#111').fontSize(8).font('Helvetica');
        doc.text(String(itemId), tableLeft + 4, y + 5, { width: colId - 8, align: 'center' });
        doc.text(description, tableLeft + colId + 4, y + 5, { width: colDesc - 8 });
        doc.text(fmt(amount), tableLeft + colId + colDesc + 4, y + 5, { width: colAmt - 8, align: 'right' });

        y += rowHeight;

        // Page break check
        if (y > doc.page.height - 180) {
          doc.addPage({ margin: 40, size: 'A4' });
          y = M;
        }
      });

      // Fill remaining rows to maintain table structure (min 5 empty rows if less than 5 items)
      const emptyRows = Math.max(0, 5 - printableItems.length);
      for (let i = 0; i < emptyRows; i++) {
        const bgColor = (printableItems.length + i) % 2 === 0 ? 'white' : '#f9fafb';
        doc.rect(tableLeft, y, CW, rowHeight).fill(bgColor);
        doc.rect(tableLeft, y, CW, rowHeight).strokeColor('#cfd7ea').lineWidth(0.3).stroke();
        doc.moveTo(tableLeft + colId, y).lineTo(tableLeft + colId, y + rowHeight).strokeColor('#cfd7ea').lineWidth(0.3).stroke();
        doc.moveTo(tableLeft + colId + colDesc, y).lineTo(tableLeft + colId + colDesc, y + rowHeight).strokeColor('#cfd7ea').lineWidth(0.3).stroke();
        y += rowHeight;
      }

      // Table bottom border
      doc.moveTo(tableLeft, y).lineTo(tableLeft + CW, y).strokeColor(PRIMARY).lineWidth(1).stroke();

      y += 16;

      // ── Totals and Signature Section (side by side) ────────────────────
      const sigX = M;
      const totalsX = M + CW - 220;
      const totalsW = 220;
      const startY = y;

      // Signature section (left)
      const sigLineY = startY + 50;
      doc.moveTo(sigX, sigLineY).lineTo(sigX + 200, sigLineY).strokeColor(PRIMARY).lineWidth(0.8).stroke();
      doc.fillColor(PRIMARY).fontSize(8).font('Helvetica-Bold')
        .text('SUPER SHINE CARGO SERVICES', sigX, sigLineY + 4);
      doc.text('MANAGER', sigX, sigLineY + 15);

      // Totals box (right)
      const boxPad = 10;
      let totY = startY;

      doc.rect(totalsX, totY, totalsW, advancePayment > 0 ? 70 : 55)
        .strokeColor(PRIMARY).lineWidth(1.5).stroke();
      doc.rect(totalsX, totY, totalsW, advancePayment > 0 ? 70 : 55)
        .fill(SOFT_BG);
      // Re-draw border on top of fill
      doc.rect(totalsX, totY, totalsW, advancePayment > 0 ? 70 : 55)
        .strokeColor(PRIMARY).lineWidth(1.5).stroke();

      totY += boxPad;

      // Gross Total
      doc.fillColor('#111').fontSize(9).font('Helvetica')
        .text('GROSS TOTAL', totalsX + boxPad, totY, { width: totalsW - 80 - boxPad });
      doc.text(fmt(grossTotal), totalsX + totalsW - 90, totY, { width: 80, align: 'right' });
      totY += 16;

      // Advance payment deduction
      if (advancePayment > 0) {
        const advLabel = advancePaymentDate
          ? `Advance payment (${fmtDate(advancePaymentDate)})`
          : 'Advance payment';
        doc.fillColor('#111').fontSize(8).font('Helvetica')
          .text(advLabel, totalsX + boxPad, totY, { width: totalsW - 80 - boxPad });
        doc.text(fmt(advancePayment), totalsX + totalsW - 90, totY, { width: 80, align: 'right' });
        totY += 16;
      }

      // Divider before total
      doc.moveTo(totalsX + boxPad, totY - 2).lineTo(totalsX + totalsW - boxPad, totY - 2)
        .strokeColor(PRIMARY).lineWidth(1.5).stroke();
      totY += 4;

      // Net Total
      doc.fillColor(PRIMARY).fontSize(10).font('Helvetica-Bold')
        .text('Total Due Amount', totalsX + boxPad, totY, { width: totalsW - 80 - boxPad });
      doc.text(fmt(advancePayment > 0 ? netTotal : grossTotal), totalsX + totalsW - 90, totY, { width: 80, align: 'right' });

      // ── Footer ─────────────────────────────────────────────────────────
      const footerY = doc.page.height - 55;
      doc.moveTo(M, footerY).lineTo(M + CW, footerY).strokeColor(PRIMARY).lineWidth(0.8).stroke();
      doc.fillColor(ACCENT).fontSize(7.5).font('Helvetica')
        .text('No 04, Marine Drive, Colombo 01, Sri Lanka', M, footerY + 6, { width: CW, align: 'center' });
      doc.text('Tel: +94 11 244 5566  |  Email: info@supershinecargo.com  |  Web: www.supershinecargo.com', M, footerY + 17, { width: CW, align: 'center' });

      doc.end();
    });
  }
}

module.exports = ExportBillPDF;
