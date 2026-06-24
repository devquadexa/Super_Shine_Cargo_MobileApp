/**
 * MSSQL Password Reset Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const IPasswordResetRepository = require('../../domain/repositories/IPasswordResetRepository');
const PasswordResetRequest = require('../../domain/entities/PasswordResetRequest');

class MSSQLPasswordResetRepository extends IPasswordResetRepository {
  constructor(dbConnection, sql) {
    super();
    this.db = dbConnection;
    this.sql = sql;
  }

  async create(passwordResetRequest) {
    const pool = await this.db();

    await pool.request()
      .input('RequestId',   this.sql.VarChar(50),    passwordResetRequest.requestId)
      .input('UserId',      this.sql.VarChar(50),    passwordResetRequest.userId)
      .input('RequestedBy', this.sql.VarChar(50),    passwordResetRequest.requestedBy)
      .input('RequestDate', this.sql.DateTime,       passwordResetRequest.requestDate)
      .input('Status',      this.sql.VarChar(50),    passwordResetRequest.status)
      .input('Notes',       this.sql.NVarChar(4000), passwordResetRequest.notes)
      .execute('usp_CreatePasswordResetRequest');

    return passwordResetRequest;
  }

  async findById(requestId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('RequestId', this.sql.VarChar(50), requestId)
      .execute('usp_GetPasswordResetRequestById');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async findByUserId(userId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('UserId', this.sql.VarChar(50), userId)
      .execute('usp_GetPasswordResetRequestsByUser');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findPendingRequests() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetPendingPasswordResetRequests');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findAll() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetAllPasswordResetRequests');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async updateStatus(requestId, status, resolvedBy, notes = null) {
    const pool = await this.db();

    await pool.request()
      .input('RequestId',    this.sql.VarChar(50),    requestId)
      .input('Status',       this.sql.VarChar(50),    status)
      .input('ResolvedBy',   this.sql.VarChar(50),    resolvedBy)
      .input('ResolvedDate', this.sql.DateTime,       new Date())
      .input('Notes',        this.sql.NVarChar(4000), notes)
      .execute('usp_UpdatePasswordResetRequestStatus');
  }

  async delete(requestId) {
    const pool = await this.db();

    await pool.request()
      .input('RequestId', this.sql.VarChar(50), requestId)
      .execute('usp_DeletePasswordResetRequest');
  }

  mapToEntity(row) {
    return new PasswordResetRequest({
      requestId:       row.requestId,
      userId:          row.userId,
      userName:        row.userName,
      userFullName:    row.userFullName,
      requestedBy:     row.requestedBy,
      requestedByName: row.requestedByName,
      requestDate:     row.requestDate,
      status:          row.status,
      resolvedBy:      row.resolvedBy,
      resolvedByName:  row.resolvedByName,
      resolvedDate:    row.resolvedDate,
      notes:           row.notes,
    });
  }
}

module.exports = MSSQLPasswordResetRepository;
