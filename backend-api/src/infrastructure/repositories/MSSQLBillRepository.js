/**
 * MSSQL Bill Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const IBillRepository = require('../../domain/repositories/IBillRepository');
const Bill = require('../../domain/entities/Bill');

class MSSQLBillRepository extends IBillRepository {
  constructor(getConnection, sql) {
    super();
    this.db = getConnection;
    this.sql = sql;
  }

  async create(bill) {
    const pool = await this.db();

    await pool.request()
      .input('BillId',         this.sql.VarChar(50),    bill.billId)
      .input('JobId',          this.sql.VarChar(50),    bill.jobId)
      .input('CustomerId',     this.sql.VarChar(50),    bill.customerId)
      .input('Amount',         this.sql.Decimal(10, 2), bill.amount || bill.billingAmount)
      .input('Tax',            this.sql.Decimal(10, 2), bill.tax)
      .input('Total',          this.sql.Decimal(10, 2), bill.total)
      .input('ActualCost',     this.sql.Decimal(10, 2), bill.actualCost)
      .input('BillingAmount',  this.sql.Decimal(10, 2), bill.billingAmount)
      .input('Profit',         this.sql.Decimal(10, 2), bill.profit)
      .input('AdvancePayment', this.sql.Decimal(18, 2), bill.advancePayment || 0.00)
      .input('GrossTotal',     this.sql.Decimal(18, 2), bill.grossTotal     || bill.billingAmount)
      .input('NetTotal',       this.sql.Decimal(18, 2), bill.netTotal       || bill.billingAmount)
      .input('PaymentStatus',  this.sql.VarChar(50),    bill.paymentStatus)
      .input('InvoiceNumber',  this.sql.VarChar(100),   bill.invoiceNumber)
      .input('InvoiceDate',    this.sql.DateTime,       bill.invoiceDate    || new Date())
      .input('DueDate',        this.sql.DateTime,       bill.dueDate)
      .input('IsOverdue',      this.sql.Bit,            bill.isOverdue      || false)
      .execute('usp_CreateBill');

    return bill;
  }

  async findById(billId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('BillId', this.sql.VarChar(50), billId)
      .execute('usp_GetBillById');

    return result.recordset[0] ? this.mapToEntity(result.recordset[0]) : null;
  }

  async findAll(filters = {}) {
    const pool = await this.db();

    const result = await pool.request()
      .input('PaymentStatus', this.sql.VarChar(50), filters.paymentStatus || null)
      .execute('usp_GetAllBills');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByJob(jobId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('JobId', this.sql.VarChar(50), jobId)
      .execute('usp_GetBillsByJob');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByCustomer(customerId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('CustomerId', this.sql.VarChar(50), customerId)
      .execute('usp_GetBillsByCustomer');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findUnpaid() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetUnpaidBills');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async update(billId, bill) {
    const pool = await this.db();

    await pool.request()
      .input('BillId',        this.sql.VarChar(50),    billId)
      .input('Amount',        this.sql.Decimal(10, 2), bill.amount         ?? null)
      .input('Tax',           this.sql.Decimal(10, 2), bill.tax            ?? null)
      .input('Total',         this.sql.Decimal(10, 2), bill.total          ?? null)
      .input('AdvancePayment',this.sql.Decimal(18, 2), bill.advancePayment ?? null)
      .input('GrossTotal',    this.sql.Decimal(18, 2), bill.grossTotal     ?? null)
      .input('NetTotal',      this.sql.Decimal(18, 2), bill.netTotal       ?? null)
      .input('PaymentStatus', this.sql.VarChar(50),    bill.paymentStatus  ?? null)
      .input('IsOverdue',     this.sql.Bit,            bill.isOverdue      ?? null)
      .execute('usp_UpdateBill');

    return this.findById(billId);
  }

  async markAsPaid(billId, paymentDetails = {}) {
    const bill = await this.findById(billId);
    const invoiceTotal = parseFloat(bill?.netTotal || bill?.total || 0);
    const pool = await this.db();

    await pool.request()
      .input('BillId',         this.sql.VarChar(50),    billId)
      .input('PaidDate',       this.sql.DateTime,       paymentDetails.paidDate ? new Date(paymentDetails.paidDate) : new Date())
      .input('PaidAmount',     this.sql.Decimal(18, 2), invoiceTotal)
      .input('RemainingAmount',this.sql.Decimal(18, 2), 0)
      .input('PaymentMethod',  this.sql.VarChar(50),    paymentDetails.paymentMethod  || null)
      .input('ChequeNumber',   this.sql.VarChar(100),   paymentDetails.chequeNumber   || null)
      .input('ChequeDate',     this.sql.Date,           paymentDetails.chequeDate     || null)
      .input('ChequeAmount',   this.sql.Decimal(18, 2), paymentDetails.chequeAmount   || null)
      .input('BankName',       this.sql.VarChar(100),   paymentDetails.bankName       || null)
      .execute('usp_MarkBillAsPaid');

    return this.findById(billId);
  }

  async applyPartialPayment(billId, paymentAmount, paymentDetails = {}) {
    const bill = await this.findById(billId);
    if (!bill) throw new Error('Bill not found');

    const invoiceTotal  = parseFloat(bill.netTotal || bill.total || 0);
    const currentPaid   = parseFloat(bill.paidAmount) || 0;
    const newPaidAmount = currentPaid + parseFloat(paymentAmount);
    const newRemaining  = Math.max(0, invoiceTotal - newPaidAmount);
    const newStatus     = newRemaining <= 0 ? 'Paid' : 'Partially Paid';
    const pool = await this.db();

    await pool.request()
      .input('BillId',         this.sql.VarChar(50),    billId)
      .input('PaidAmount',     this.sql.Decimal(18, 2), newPaidAmount)
      .input('RemainingAmount',this.sql.Decimal(18, 2), newRemaining)
      .input('PaymentStatus',  this.sql.VarChar(50),    newStatus)
      .input('PaidDate',       this.sql.DateTime,       paymentDetails.paidDate ? new Date(paymentDetails.paidDate) : new Date())
      .execute('usp_ApplyBillPartialPayment');

    return this.findById(billId);
  }

  async replaceBill(billId, billData) {
    const pool = await this.db();

    await pool.request()
      .input('BillId',        this.sql.VarChar(50),    billId)
      .input('CustomerId',    this.sql.VarChar(50),    billData.customerId)
      .input('Amount',        this.sql.Decimal(10, 2), billData.amount || billData.billingAmount)
      .input('Tax',           this.sql.Decimal(10, 2), billData.tax || 0)
      .input('Total',         this.sql.Decimal(10, 2), billData.total)
      .input('ActualCost',    this.sql.Decimal(10, 2), billData.actualCost)
      .input('BillingAmount', this.sql.Decimal(10, 2), billData.billingAmount)
      .input('Profit',        this.sql.Decimal(10, 2), billData.profit)
      .input('AdvancePayment',this.sql.Decimal(18, 2), billData.advancePayment || 0)
      .input('GrossTotal',    this.sql.Decimal(18, 2), billData.grossTotal)
      .input('NetTotal',      this.sql.Decimal(18, 2), billData.netTotal)
      .input('PaymentStatus', this.sql.VarChar(50),    billData.paymentStatus || 'Unpaid')
      .input('InvoiceNumber', this.sql.VarChar(100),   billData.invoiceNumber || null)
      .input('InvoiceDate',   this.sql.DateTime,       billData.invoiceDate   || new Date())
      .input('DueDate',       this.sql.DateTime,       billData.dueDate)
      .input('IsOverdue',     this.sql.Bit,            billData.isOverdue     || false)
      .execute('usp_ReplaceBill');

    return this.findById(billId);
  }

  async delete(billId) {
    const pool = await this.db();

    await pool.request()
      .input('BillId', this.sql.VarChar(50), billId)
      .execute('usp_DeleteBill');
  }

  async generateNextId() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GenerateNextBillId');

    return result.recordset[0].NextBillId;
  }

  mapToEntity(row) {
    return new Bill({
      billId:          row.BillId,
      jobId:           row.JobId,
      customerId:      row.CustomerId,
      amount:          row.Amount,
      tax:             row.Tax,
      total:           row.Total,
      actualCost:      row.ActualCost      || 0,
      billingAmount:   row.BillingAmount   || row.Amount,
      profit:          row.Profit          || 0,
      advancePayment:  row.advancePayment  || 0.00,
      grossTotal:      row.grossTotal      || row.BillingAmount || row.Amount,
      netTotal:        row.netTotal        || row.BillingAmount || row.Amount,
      paymentStatus:   row.PaymentStatus,
      createdDate:     row.CreatedDate,
      billDate:        row.BillDate        || row.CreatedDate,
      paidDate:        row.paidDate        || row.PaidDate,
      invoiceNumber:   row.InvoiceNumber,
      invoiceDate:     row.invoiceDate,
      dueDate:         row.dueDate,
      isOverdue:       row.isOverdue       || false,
      paymentMethod:   row.paymentMethod,
      chequeNumber:    row.chequeNumber,
      chequeDate:      row.chequeDate,
      chequeAmount:    row.chequeAmount,
      bankName:        row.bankName,
      paidAmount:      row.paidAmount      || 0,
      remainingAmount: row.remainingAmount !== undefined ? row.remainingAmount : (row.netTotal || row.total || 0),
    });
  }
}

module.exports = MSSQLBillRepository;
