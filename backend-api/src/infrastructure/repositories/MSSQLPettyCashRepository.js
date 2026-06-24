/**
 * MSSQL PettyCash Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const IPettyCashRepository = require('../../domain/repositories/IPettyCashRepository');
const PettyCashEntry = require('../../domain/entities/PettyCashEntry');

class MSSQLPettyCashRepository extends IPettyCashRepository {
  constructor(getConnection, sql) {
    super();
    this.db = getConnection;
    this.sql = sql;
  }

  async createEntry(entry) {
    const pool = await this.db();

    await pool.request()
      .input('EntryId',      this.sql.VarChar(50),    entry.entryId)
      .input('Description',  this.sql.VarChar(500),   entry.description)
      .input('Amount',       this.sql.Decimal(10, 2), entry.amount)
      .input('EntryType',    this.sql.VarChar(50),    entry.entryType)
      .input('JobId',        this.sql.VarChar(50),    entry.jobId || null)
      .input('CreatedBy',    this.sql.VarChar(50),    entry.createdBy)
      .input('BalanceAfter', this.sql.Decimal(10, 2), entry.balanceAfter)
      .execute('usp_CreatePettyCashEntry');

    return entry;
  }

  async findById(entryId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('EntryId', this.sql.VarChar(50), entryId)
      .execute('usp_GetPettyCashEntryById');

    return result.recordset[0] ? this.mapToEntity(result.recordset[0]) : null;
  }

  async findAll(filters = {}) {
    const pool = await this.db();

    const result = await pool.request()
      .input('EntryType',  this.sql.VarChar(50), filters.entryType  || null)
      .input('CreatedBy',  this.sql.VarChar(50), filters.createdBy  || null)
      .execute('usp_GetAllPettyCashEntries');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByJob(jobId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('JobId', this.sql.VarChar(50), jobId)
      .execute('usp_GetPettyCashEntriesByJob');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByUser(userId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('UserId', this.sql.VarChar(50), userId)
      .execute('usp_GetPettyCashEntriesByUser');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async getBalance() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetPettyCashBalance');

    return result.recordset[0]?.Balance || 0;
  }

  async updateBalance(amount) {
    const pool = await this.db();

    await pool.request()
      .input('Amount', this.sql.Decimal(10, 2), amount)
      .execute('usp_UpdatePettyCashBalance');

    return amount;
  }

  async generateNextId() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GenerateNextPettyCashId');

    return result.recordset[0].NextEntryId;
  }

  mapToEntity(row) {
    return new PettyCashEntry({
      entryId:      row.EntryId,
      description:  row.Description,
      amount:       row.Amount,
      entryType:    row.EntryType,
      jobId:        row.JobId,
      createdBy:    row.CreatedBy,
      date:         row.Date,
      balanceAfter: row.BalanceAfter,
    });
  }
}

module.exports = MSSQLPettyCashRepository;
