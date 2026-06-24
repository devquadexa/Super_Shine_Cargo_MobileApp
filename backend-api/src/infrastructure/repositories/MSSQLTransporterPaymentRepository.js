/**
 * MSSQL Transporter Payment Repository
 * All database operations are delegated to stored procedures.
 */
class MSSQLTransporterPaymentRepository {
  constructor(getConnection, sql) {
    this.getConnection = getConnection;
    this.sql = sql;
  }

  async create(paymentData) {
    const pool = await this.getConnection();
    const paymentId = `TP${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    try {
      await pool.request()
        .input('PaymentId',     this.sql.VarChar(50),     paymentId)
        .input('JobId',         this.sql.VarChar(50),     paymentData.jobId)
        .input('TransporterId', this.sql.VarChar(50),     paymentData.transporterId)
        .input('Amount',        this.sql.Decimal(18, 2),  paymentData.amount)
        .input('PaymentMethod', this.sql.VarChar(50),     paymentData.paymentMethod)
        .input('PaymentDate',   this.sql.DateTime,        paymentData.paymentDate)
        .input('Status',        this.sql.VarChar(50),     paymentData.status)
        .input('ChequeNumber',  this.sql.VarChar(100),    paymentData.chequeNumber)
        .input('ChequeDate',    this.sql.Date,            paymentData.chequeDate)
        .input('ChequeAmount',  this.sql.Decimal(18, 2),  paymentData.chequeAmount)
        .input('BankName',      this.sql.NVarChar(200),   paymentData.bankName)
        .input('PaidBy',        this.sql.VarChar(50),     paymentData.paidBy)
        .input('PaidByName',    this.sql.NVarChar(200),   paymentData.paidByName)
        .input('Notes',         this.sql.NVarChar(4000),  paymentData.notes)
        .execute('usp_CreateTransporterPayment');

      return { paymentId, ...paymentData, createdDate: new Date() };
    } catch (error) {
      console.error('Error creating transporter payment:', error);
      throw error;
    }
  }

  async findByTransporterId(transporterId, filters = {}) {
    const pool = await this.getConnection();

    try {
      const result = await pool.request()
        .input('TransporterId', this.sql.VarChar(50),  transporterId)
        .input('Status',        this.sql.VarChar(50),  filters.status   || null)
        .input('FromDate',      this.sql.DateTime,     filters.fromDate ? new Date(filters.fromDate) : null)
        .input('ToDate',        this.sql.DateTime,     filters.toDate   ? new Date(filters.toDate)   : null)
        .execute('usp_GetTransporterPaymentsByTransporterId');

      return result.recordset || [];
    } catch (error) {
      console.error('Error fetching transporter payments:', error);
      throw error;
    }
  }

  async findByJobId(jobId) {
    const pool = await this.getConnection();

    try {
      const result = await pool.request()
        .input('JobId', this.sql.VarChar(50), jobId)
        .execute('usp_GetTransporterPaymentsByJobId');

      return result.recordset || [];
    } catch (error) {
      console.error('Error fetching payments for job:', error);
      throw error;
    }
  }

  async findById(paymentId) {
    const pool = await this.getConnection();

    try {
      const result = await pool.request()
        .input('PaymentId', this.sql.VarChar(50), paymentId)
        .execute('usp_GetTransporterPaymentById');

      return result.recordset?.[0] || null;
    } catch (error) {
      console.error('Error fetching transporter payment:', error);
      throw error;
    }
  }

  async updateStatus(paymentId, status) {
    const pool = await this.getConnection();

    try {
      const result = await pool.request()
        .input('PaymentId', this.sql.VarChar(50), paymentId)
        .input('Status',    this.sql.VarChar(50), status)
        .execute('usp_UpdateTransporterPaymentStatus');

      if (result.rowsAffected[0] === 0) {
        throw new Error('Payment not found');
      }

      return await this.findById(paymentId);
    } catch (error) {
      console.error('Error updating payment status:', error);
      throw error;
    }
  }

  async getOutstandingBalance(transporterId) {
    const pool = await this.getConnection();

    try {
      const result = await pool.request()
        .input('TransporterId', this.sql.VarChar(50), transporterId)
        .execute('usp_GetTransporterOutstandingBalance');

      return result.recordset?.[0]?.TotalOutstanding || 0;
    } catch (error) {
      console.error('Error calculating outstanding balance:', error);
      throw error;
    }
  }
}

module.exports = MSSQLTransporterPaymentRepository;
