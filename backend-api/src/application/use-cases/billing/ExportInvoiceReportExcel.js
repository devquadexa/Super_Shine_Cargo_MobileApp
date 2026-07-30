/**
 * Export Invoice Report to Excel
 * Generates a professional Excel report of all generated invoices
 */
const ExcelJS = require('exceljs');

class ExportInvoiceReportExcel {
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
      paymentStatus: row.PaymentStatus || 'Unpaid',
      isOverdue: row.isOverdue || false
    }));

    const totalBilling = invoices.reduce((s, i) => s + i.netTotal, 0);
    const totalPaid = invoices.reduce((s, i) => s + i.paidAmount, 0);
    const totalOutstanding = totalBilling - totalPaid;

    const fmtDate = (d) => d ? new Date(d).toLocaleDateString('en-GB') : '-';
    const isSingleDay = fromDateStr === toDateStr;
    const dateLabel = isSingleDay ? `Report Date: ${fmtDate(fromDate)}` : `Period: ${fmtDate(fromDate)} — ${fmtDate(toDate)}`;

    // Build Workbook
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'Super Shine Cargo Service';
    workbook.created = new Date();

    const sheet = workbook.addWorksheet('Invoice Report', {
      pageSetup: { paperSize: 9, orientation: 'landscape', fitToPage: true, fitToWidth: 1 }
    });

    const DARK_FILL = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF101036' } };
    const BLUE_FILL = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1e3a8a' } };
    const WHITE_FILL = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFFFFF' } };
    const ALT_FILL = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF9FAFB' } };
    const TOTAL_FILL = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFEFF6FF' } };

    const WHITE_FONT = { color: { argb: 'FFFFFFFF' }, bold: true };
    const BLUE_FONT = { color: { argb: 'FF1e3a8a' }, bold: true };
    const BODY_FONT = { color: { argb: 'FF374151' } };
    const GREEN_FONT = { color: { argb: 'FF065F46' }, bold: true };
    const RED_FONT = { color: { argb: 'FFDC2626' }, bold: true };
    const AMBER_FONT = { color: { argb: 'FF92400E' }, bold: true };

    const THIN_BORDER = {
      top: { style: 'thin', color: { argb: 'FFE5E7EB' } },
      left: { style: 'thin', color: { argb: 'FFE5E7EB' } },
      bottom: { style: 'thin', color: { argb: 'FFE5E7EB' } },
      right: { style: 'thin', color: { argb: 'FFE5E7EB' } },
    };

    sheet.columns = [
      { key: 'num', width: 6 },
      { key: 'invoiceNum', width: 16 },
      { key: 'jobId', width: 14 },
      { key: 'customer', width: 28 },
      { key: 'invoiceDate', width: 14 },
      { key: 'dueDate', width: 14 },
      { key: 'billingAmt', width: 18 },
      { key: 'paidAmt', width: 18 },
      { key: 'outstanding', width: 18 },
      { key: 'status', width: 16 },
    ];

    // Row 1: Company header
    sheet.mergeCells('A1:J1');
    const titleCell = sheet.getCell('A1');
    titleCell.value = 'SUPER SHINE CARGO SERVICE';
    titleCell.font = { ...WHITE_FONT, size: 14 };
    titleCell.fill = DARK_FILL;
    titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
    sheet.getRow(1).height = 28;

    // Row 2: Sub-title
    sheet.mergeCells('A2:F2');
    const subCell = sheet.getCell('A2');
    subCell.value = `Generated Invoices Report (${statusFilter})`;
    subCell.font = { ...WHITE_FONT, bold: false, size: 10 };
    subCell.fill = DARK_FILL;
    subCell.alignment = { horizontal: 'left', vertical: 'middle', indent: 1 };

    sheet.mergeCells('G2:J2');
    const dateCell = sheet.getCell('G2');
    dateCell.value = dateLabel;
    dateCell.font = { ...WHITE_FONT, bold: false, size: 10 };
    dateCell.fill = DARK_FILL;
    dateCell.alignment = { horizontal: 'right', vertical: 'middle', indent: 1 };
    sheet.getRow(2).height = 20;

    // Row 3: spacer
    sheet.getRow(3).height = 6;

    // Row 4: Table header
    const headers = ['#', 'Invoice #', 'Job ID', 'Customer', 'Invoice Date', 'Due Date', 'Billing (LKR)', 'Paid (LKR)', 'Outstanding (LKR)', 'Status'];
    const headerRow = sheet.getRow(4);
    headers.forEach((h, i) => {
      const cell = headerRow.getCell(i + 1);
      cell.value = h;
      cell.font = WHITE_FONT;
      cell.fill = BLUE_FILL;
      cell.alignment = { horizontal: i >= 6 && i <= 8 ? 'right' : 'center', vertical: 'middle' };
      cell.border = THIN_BORDER;
    });
    headerRow.height = 20;

    // Data rows
    invoices.forEach((inv, idx) => {
      const rowNum = 5 + idx;
      const row = sheet.getRow(rowNum);
      const fill = idx % 2 === 0 ? WHITE_FILL : ALT_FILL;
      const outstanding = inv.netTotal - inv.paidAmount;

      const statusFont = inv.paymentStatus === 'Paid' ? GREEN_FONT :
        inv.paymentStatus === 'Partially Paid' ? AMBER_FONT : RED_FONT;

      const cells = [
        { v: idx + 1, fmt: '0', align: 'center' },
        { v: inv.invoiceNumber || '-', fmt: '@', align: 'left' },
        { v: inv.jobId || '-', fmt: '@', align: 'left' },
        { v: inv.customerName, fmt: '@', align: 'left' },
        { v: fmtDate(inv.invoiceDate), fmt: '@', align: 'center' },
        { v: fmtDate(inv.dueDate), fmt: '@', align: 'center' },
        { v: inv.netTotal, fmt: '#,##0.00', align: 'right' },
        { v: inv.paidAmount, fmt: '#,##0.00', align: 'right', font: GREEN_FONT },
        { v: outstanding, fmt: '#,##0.00', align: 'right', font: outstanding > 0 ? AMBER_FONT : BODY_FONT },
        { v: inv.paymentStatus, fmt: '@', align: 'center', font: statusFont },
      ];

      cells.forEach((c, ci) => {
        const cell = row.getCell(ci + 1);
        cell.value = c.v;
        cell.numFmt = c.fmt;
        cell.font = c.font || BODY_FONT;
        cell.fill = fill;
        cell.alignment = { horizontal: c.align, vertical: 'middle' };
        cell.border = THIN_BORDER;
      });
      row.height = 18;
    });

    // Totals row
    const totalRowNum = 5 + invoices.length;
    const totalRow = sheet.getRow(totalRowNum);
    const totalValues = ['', '', '', `TOTAL (${invoices.length} invoices)`, '', '', totalBilling, totalPaid, totalOutstanding, ''];
    totalValues.forEach((v, i) => {
      const cell = totalRow.getCell(i + 1);
      cell.value = v;
      cell.numFmt = i >= 6 && i <= 8 ? '#,##0.00' : '@';
      cell.font = BLUE_FONT;
      cell.fill = TOTAL_FILL;
      cell.alignment = { horizontal: i >= 6 && i <= 8 ? 'right' : i === 3 ? 'left' : 'center', vertical: 'middle' };
      cell.border = { ...THIN_BORDER, top: { style: 'medium', color: { argb: 'FF1e3a8a' } } };
    });
    totalRow.height = 20;

    return await workbook.xlsx.writeBuffer();
  }
}

module.exports = ExportInvoiceReportExcel;
