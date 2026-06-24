/**
 * MSSQL Cash Withdrawal Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const ICashWithdrawalRepository = require('../../domain/repositories/ICashWithdrawalRepository');
const CashWithdrawal = require('../../domain/entities/CashWithdrawal');

class MSSQLCashWithdrawalRepository extends ICashWithdrawalRepository {
  constructor(getConnection, sql) {
    super();
    this.db = getConnection;
    this.sql = sql;
  }

  async create(withdrawal) {
    const pool = await this.db();

    await pool.request()
      .input('WithdrawalId',   this.sql.VarChar(50),    withdrawal.withdrawalId)
      .input('Amount',         this.sql.Decimal(18, 2), withdrawal.amount)
      .input('BankName',       this.sql.NVarChar(200),  withdrawal.bankName)
      .input('WithdrawalDate', this.sql.DateTime,       withdrawal.withdrawalDate)
      .input('Notes',          this.sql.NVarChar(500),  withdrawal.notes || null)
      .input('TransactionType',this.sql.NVarChar(50),   withdrawal.transactionType || 'withdrawal')
      .input('CreatedBy',      this.sql.VarChar(50),    withdrawal.createdBy)
      .execute('usp_CreateCashWithdrawal');

    return withdrawal;
  }

  async findAll() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetAllCashWithdrawals');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findById(withdrawalId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('WithdrawalId', this.sql.VarChar(50), withdrawalId)
      .execute('usp_GetCashWithdrawalById');

    return result.recordset[0] ? this.mapToEntity(result.recordset[0]) : null;
  }

  async findByDateRange(fromDate, toDate) {
    const pool = await this.db();

    const result = await pool.request()
      .input('FromDate', this.sql.Date, fromDate)
      .input('ToDate',   this.sql.Date, toDate)
      .execute('usp_GetCashWithdrawalsByDateRange');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async generateNextId() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GenerateNextCashWithdrawalId');

    return result.recordset[0].NextWithdrawalId;
  }

  mapToEntity(row) {
    return new CashWithdrawal({
      withdrawalId:    row.withdrawalId,
      amount:          row.amount,
      bankName:        row.bankName,
      withdrawalDate:  row.withdrawalDate,
      notes:           row.notes,
      transactionType: row.transactionType || 'withdrawal',
      createdBy:       row.createdBy,
      createdAt:       row.createdAt,
      createdByName:   row.createdByName,
    });
  }
}

module.exports = MSSQLCashWithdrawalRepository;
