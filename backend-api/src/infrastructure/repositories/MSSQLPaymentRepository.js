/**
 * MSSQL Payment Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const IPaymentRepository = require('../../domain/repositories/IPaymentRepository');
const Payment = require('../../domain/entities/Payment');

class MSSQLPaymentRepository extends IPaymentRepository {
  constructor(getConnection, sql) {
    super();
    this.db = getConnection;
    this.sql = sql;
  }

  async create(payment) {
    const pool = await this.db();

    await pool.request()
      .input('PaymentId',       this.sql.VarChar(50),    payment.paymentId)
      .input('JobId',           this.sql.VarChar(50),    payment.jobId)
      .input('CustomerId',      this.sql.VarChar(20),    payment.customerId)
      .input('CustomerName',    this.sql.NVarChar(255),  payment.customerName)
      .input('InvoiceNumber',   this.sql.VarChar(100),   payment.invoiceNumber)
      .input('BillId',          this.sql.VarChar(50),    payment.billId)
      .input('PaymentMethod',   this.sql.VarChar(50),    payment.paymentMethod)
      .input('PaymentDate',     this.sql.DateTime,       payment.paymentDate)
      .input('Amount',          this.sql.Decimal(18, 2), payment.amount)
      .input('Status',          this.sql.VarChar(50),    payment.status || 'Pending')
      .input('ChequeNumber',    this.sql.VarChar(100),   payment.chequeNumber    || null)
      .input('ChequeDate',      this.sql.Date,           payment.chequeDate      || null)
      .input('ChequeAmount',    this.sql.Decimal(18, 2), payment.chequeAmount    || null)
      .input('BankName',        this.sql.NVarChar(200),  payment.bankName        || null)
      .input('ReferenceNumber', this.sql.VarChar(100),   payment.referenceNumber || null)
      .input('Notes',           this.sql.NVarChar(4000), payment.notes           || null)
      .input('CreatedBy',       this.sql.VarChar(50),    payment.createdBy       || null)
      .execute('usp_CreatePayment');

    return payment;
  }

  async findById(paymentId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('PaymentId', this.sql.VarChar(50), paymentId)
      .execute('usp_GetPaymentById');

    return result.recordset[0] ? this.mapToEntity(result.recordset[0]) : null;
  }

  async findAll(filters = {}) {
    const pool = await this.db();

    const result = await pool.request()
      .input('Status',        this.sql.VarChar(50),  filters.status        || null)
      .input('PaymentMethod', this.sql.VarChar(50),  filters.paymentMethod || null)
      .input('CustomerId',    this.sql.VarChar(20),  filters.customerId    || null)
      .input('JobId',         this.sql.VarChar(50),  filters.jobId         || null)
      .execute('usp_GetAllPayments');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByJob(jobId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('JobId', this.sql.VarChar(50), jobId)
      .execute('usp_GetPaymentsByJob');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByCustomer(customerId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('CustomerId', this.sql.VarChar(20), customerId)
      .execute('usp_GetPaymentsByCustomer');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByBillId(billId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('BillId', this.sql.VarChar(50), billId)
      .execute('usp_GetPaymentsByBillId');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByChequeNumber(chequeNumber) {
    const pool = await this.db();

    const result = await pool.request()
      .input('ChequeNumber', this.sql.VarChar(100), chequeNumber)
      .execute('usp_GetPaymentsByChequeNumber');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByStatus(status) {
    const pool = await this.db();

    const result = await pool.request()
      .input('Status', this.sql.VarChar(50), status)
      .execute('usp_GetPaymentsByStatus');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByPaymentMethod(paymentMethod) {
    const pool = await this.db();

    const result = await pool.request()
      .input('PaymentMethod', this.sql.VarChar(50), paymentMethod)
      .execute('usp_GetPaymentsByMethod');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async updateStatus(paymentId, status, statusDate = new Date()) {
    const pool = await this.db();

    await pool.request()
      .input('PaymentId',  this.sql.VarChar(50), paymentId)
      .input('Status',     this.sql.VarChar(50), status)
      .input('StatusDate', this.sql.DateTime,    statusDate)
      .execute('usp_UpdatePaymentStatus');

    return this.findById(paymentId);
  }

  async update(paymentId, payment) {
    const pool = await this.db();

    await pool.request()
      .input('PaymentId',       this.sql.VarChar(50),    paymentId)
      .input('Status',          this.sql.VarChar(50),    payment.status          ?? null)
      .input('Amount',          this.sql.Decimal(18, 2), payment.amount          ?? null)
      .input('ChequeNumber',    this.sql.VarChar(100),   payment.chequeNumber    ?? null)
      .input('ChequeDate',      this.sql.Date,           payment.chequeDate      ?? null)
      .input('BankName',        this.sql.NVarChar(200),  payment.bankName        ?? null)
      .input('ReferenceNumber', this.sql.VarChar(100),   payment.referenceNumber ?? null)
      .input('Notes',           this.sql.NVarChar(4000), payment.notes           ?? null)
      .execute('usp_UpdatePayment');

    return this.findById(paymentId);
  }

  async delete(paymentId) {
    const pool = await this.db();

    await pool.request()
      .input('PaymentId', this.sql.VarChar(50), paymentId)
      .execute('usp_DeletePayment');
  }

  async generateNextId() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GenerateNextPaymentId');

    return result.recordset[0].NextPaymentId;
  }

  mapToEntity(row) {
    return new Payment({
      paymentId:       row.PaymentId,
      jobId:           row.JobId,
      customerId:      row.CustomerId,
      customerName:    row.CustomerName,
      invoiceNumber:   row.InvoiceNumber,
      billId:          row.BillId,
      paymentMethod:   row.PaymentMethod,
      paymentDate:     row.PaymentDate,
      amount:          row.Amount,
      status:          row.Status,
      chequeNumber:    row.ChequeNumber,
      chequeDate:      row.ChequeDate,
      chequeAmount:    row.ChequeAmount,
      bankName:        row.BankName,
      referenceNumber: row.ReferenceNumber,
      clearedDate:     row.ClearedDate,
      bouncedDate:     row.BouncedDate,
      notes:           row.Notes,
      createdBy:       row.CreatedBy,
      createdDate:     row.CreatedDate,
      updatedDate:     row.UpdatedDate,
      cusdecNumber:    row.CUSDECNumber,
      cusdecDate:      row.CUSDECDate,
    });
  }
}

module.exports = MSSQLPaymentRepository;
