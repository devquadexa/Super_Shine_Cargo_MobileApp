/**
 * Export Invoice Report to PDF
 * Generates a professional PDF report of all generated invoices
 */
const PDFDocument = require('pdfkit');

class ExportInvoiceReportPDF {
  constructor(billRepository) {
    this.billRepository = billRepository;
  }

  async execute(fromDate, toDate, statusFilter = 'All') {
    if (!fromDate) throw new Error('From date is required');
    const effectiveTo = toDate || fromDate;

    const from = new Date(fromDate);
    const to = new Date(effectiveTo);
    if (isNaN(from.getTime())) throw new Error('Invalid from date. Use YYYY-MM-DD');
    if (isNaN(to.getTime())) throw new Error('Invalid to date. Use YYYY-MM-DD');

    const pool = await this.billRepository.db();
    const fromDateStr = from.toISOString().split('T')[0];
    const toDateStr = to.toISOString().split('T')[0];

    const request = pool.request()
      .input('fromDate', this.billRepository.sql.VarChar, fromDateStr)
      .input('toDate', this.billRepository.sql.VarChar, toDateStr);

    let whereClause = `WHERE CONVERT(DATE, ISNULL(b.invoiceDate, b.CreatedDate)) BETWEEN CONVERT(DATE, @fromDate) AND CONVERT(DATE, @toDate)`;
    if (statusFilter && statusFilter !== 'All') {
      request.input('status', this.billRepository.sql.VarChar, statusFilter);
      whereClause += ` AND b.PaymentStatus = @status`;
    }

    const result = await request.query(`
      SELECT 
        b.BillId, b.JobId, b.InvoiceNumber, b.invoiceDate, b.dueDate,
        b.netTotal, b.BillingAmount, b.Amount, b.paidAmount, b.remainingAmount,
        b.PaymentStatus, b.isOverdue, b.CreatedDate,
        c.Name as customerName
      FROM Bills b
      LEFT JOIN Customers c ON b.CustomerId = c.customerId
      ${whereClause}
      ORDER BY b.invoiceDate DESC, b.JobId ASC
    `);

    if (!result.recordset || result.recordset.length === 0) {
      throw new Error('No invoices found for the selected date range');
    }

    const invoices = result.recordset.map(row => ({
      billId: row.BillId,
      jobId: row.JobId,
      customerName: row.customerName || '-',
      invoiceNumber: row.InvoiceNumber || row.BillId,
      invoiceDate: row.invoiceDate || row.CreatedDate,
      dueDate: row.dueDate,
      netTotal: parseFloat(row.netTotal) || parseFloat(row.BillingAmount) || parseFloat(row.Amount) || 0,
      paidAmount: parseFloat(row.paidAmount) || 0,
      remainingAmount: parseFloat(row.remainingAmount) || (parseFloat(row.netTotal) || 0) - (parseFloat(row.paidAmount) || 0),
      paymentStatus: row.PaymentStatus || 'Unpaid',
      isOverdue: row.isOverdue || false
    }));

    const totalBilling = invoices.reduce((s, i) => s + i.netTotal, 0);
    const totalPaid = invoices.reduce((s, i) => s + i.paidAmount, 0);
    const totalOutstanding = totalBilling - totalPaid;

    const fmt = (v) => `LKR ${new Intl.NumberFormat('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(v)}`;
    const fmtDate = (d) => d ? new Date(d).toLocaleDateString('en-GB') : '-';

    const isSingleDay = fromDateStr === toDateStr;
    const dateLabel = isSingleDay ? `Date: ${fmtDate(fromDate)}` : `Period: ${fmtDate(fromDate)} — ${fmtDate(toDate)}`;

    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({ margin: 20, size: 'A4', layout: 'landscape' });
      const chunks = [];
      doc.on('data', c => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const W = doc.page.width;
      const DARK = '#101036';
      const BLUE = '#1e3a8a';
      const GRAY = '#6b7280';
      const GREEN = '#065f46';
      const RED = '#dc2626';
      const AMBER = '#92400e';

      // Header
      doc.rect(0, 0, W, 60).fill(DARK);
      doc.fillColor('white').fontSize(14).font('Helvetica-Bold').text('SUPER SHINE CARGO SERVICE', 20, 15);
      doc.fontSize(8).font('Helvetica').text('Generated Invoices Report', 20, 35);
      doc.fontSize(7).text(`${dateLabel}  |  Total: ${invoices.length} invoices  |  Status: ${statusFilter}`, 20, 48);

      // Table
      const tableTop = 75;
      const cols = [
        { label: '#', width: 22, align: 'center' },
        { label: 'Invoice #', width: 65, align: 'left' },
        { label: 'Job ID', width: 55, align: 'left' },
        { label: 'Customer', width: 120, align: 'left' },
        { label: 'Invoice Date', width: 60, align: 'center' },
        { label: 'Due Date', width: 60, align: 'center' },
        { label: 'Billing Amount', width: 80, align: 'right' },
        { label: 'Paid', width: 70, align: 'right' },
        { label: 'Outstanding', width: 75, align: 'right' },
        { label: 'Status', width: 55, align: 'center' },
      ];

      const drawHeader = (y) => {
        doc.rect(20, y, W - 40, 18).fill(DARK);
        let cx = 20;
        cols.forEach(col => {
          doc.fillColor('white').fontSize(6.5).font('Helvetica-Bold')
            .text(col.label, cx + 3, y + 6, { width: col.width - 6, align: col.align });
          cx += col.width;
        });
        return y + 18;
      };

      let rowY = drawHeader(tableTop);
      const rowH = 16;

      invoices.forEach((inv, idx) => {
        const bg = idx % 2 === 0 ? 'white' : '#f9fafb';
        doc.rect(20, rowY, W - 40, rowH).fill(bg);

        const outstanding = inv.netTotal - inv.paidAmount;
        const cells = [
          { v: String(idx + 1), align: 'center' },
          { v: inv.invoiceNumber || '-', align: 'left' },
          { v: inv.jobId || '-', align: 'left' },
          { v: inv.customerName, align: 'left' },
          { v: fmtDate(inv.invoiceDate), align: 'center' },
          { v: fmtDate(inv.dueDate), align: 'center' },
          { v: fmt(inv.netTotal), align: 'right' },
          { v: fmt(inv.paidAmount), align: 'right', color: GREEN },
          { v: outstanding > 0 ? fmt(outstanding) : '-', align: 'right', color: outstanding > 0 ? AMBER : GRAY },
          { v: inv.paymentStatus, align: 'center', color: inv.paymentStatus === 'Paid' ? GREEN : inv.paymentStatus === 'Partially Paid' ? AMBER : RED },
        ];

        let cx = 20;
        cells.forEach((cell, ci) => {
          doc.fillColor(cell.color || '#374151').fontSize(6).font('Helvetica')
            .text(cell.v, cx + 3, rowY + 5, { width: cols[ci].width - 6, align: cell.align, ellipsis: true });
          cx += cols[ci].width;
        });

        doc.moveTo(20, rowY + rowH).lineTo(W - 20, rowY + rowH).strokeColor('#e5e7eb').lineWidth(0.5).stroke();
        rowY += rowH;

        if (rowY > doc.page.height - 70) {
          doc.addPage({ margin: 20, size: 'A4', layout: 'landscape' });
          rowY = drawHeader(40);
        }
      });

      // Totals
      doc.rect(20, rowY, W - 40, 18).fill('#eff6ff');
      let cx = 20;
      const totalCells = [
        { v: '', align: 'center' }, { v: '', align: 'left' }, { v: '', align: 'left' },
        { v: `TOTAL (${invoices.length} invoices)`, align: 'left' },
        { v: '', align: 'center' }, { v: '', align: 'center' },
        { v: fmt(totalBilling), align: 'right' },
        { v: fmt(totalPaid), align: 'right' },
        { v: fmt(totalOutstanding), align: 'right' },
        { v: '', align: 'center' },
      ];
      totalCells.forEach((cell, ci) => {
        doc.fillColor(BLUE).fontSize(6.5).font('Helvetica-Bold')
          .text(cell.v, cx + 3, rowY + 6, { width: cols[ci].width - 6, align: cell.align });
        cx += cols[ci].width;
      });

      // Footer
      const footerY = doc.page.height - 25;
      doc.moveTo(20, footerY - 6).lineTo(W - 20, footerY - 6).strokeColor('#e5e7eb').lineWidth(0.5).stroke();
      doc.fillColor(GRAY).fontSize(6.5).font('Helvetica')
        .text(`Super Shine Cargo Service — Confidential | Generated: ${fmtDate(new Date())}`, 20, footerY, { width: W - 40, align: 'center' });

      doc.end();
    });
  }
}

module.exports = ExportInvoiceReportPDF;
