/**
 * MSSQL Cash Balance Settlement Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const CashBalanceSettlement = require('../../domain/entities/CashBalanceSettlement');

class MSSQLCashBalanceSettlementRepository {
  constructor(getConnection, sql) {
    this.db = getConnection;
    this.sql = sql;
  }

  async create(settlement) {
    const pool = await this.db();

    await pool.request()
      .input('SettlementId',       this.sql.VarChar(50),    settlement.settlementId)
      .input('UserId',             this.sql.VarChar(50),    settlement.userId)
      .input('UserName',           this.sql.NVarChar(255),  settlement.userName)
      .input('ManagerId',          this.sql.VarChar(50),    settlement.managerId)
      .input('ManagerName',        this.sql.NVarChar(255),  settlement.managerName)
      .input('SettlementType',     this.sql.NVarChar(100),  settlement.settlementType)
      .input('Amount',             this.sql.Decimal(18, 2), settlement.amount)
      .input('Status',             this.sql.NVarChar(50),   settlement.status)
      .input('RequestDate',        this.sql.DateTime,       settlement.requestDate)
      .input('Notes',              this.sql.NVarChar(4000), settlement.notes)
      .input('RelatedAssignments', this.sql.NVarChar(4000), JSON.stringify(settlement.relatedAssignments || []))
      .input('CreatedBy',          this.sql.VarChar(50),    settlement.createdBy)
      .input('CreatedDate',        this.sql.DateTime,       settlement.createdDate)
      .execute('usp_CreateCashBalanceSettlement');

    return settlement;
  }

  async findById(settlementId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('SettlementId', this.sql.VarChar(50), settlementId)
      .execute('usp_GetCashBalanceSettlementById');

    return result.recordset[0] ? this.mapToEntity(result.recordset[0]) : null;
  }

  async findAll(filters = {}) {
    const pool = await this.db();

    const result = await pool.request()
      .input('UserId',         this.sql.VarChar(50),   filters.userId         || null)
      .input('ManagerId',      this.sql.VarChar(50),   filters.managerId      || null)
      .input('Status',         this.sql.NVarChar(50),  filters.status         || null)
      .input('SettlementType', this.sql.NVarChar(100), filters.settlementType || null)
      .execute('usp_GetAllCashBalanceSettlements');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByUser(userId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('UserId', this.sql.VarChar(50), userId)
      .execute('usp_GetCashBalanceSettlementsByUser');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByManager(managerId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('ManagerId', this.sql.VarChar(50), managerId)
      .execute('usp_GetCashBalanceSettlementsByManager');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findPendingSettlements() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetPendingCashBalanceSettlements');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findApprovedSettlements() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetApprovedCashBalanceSettlements');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findRejectedSettlements() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetRejectedCashBalanceSettlements');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async update(settlementId, settlement) {
    const pool = await this.db();

    await pool.request()
      .input('SettlementId',   this.sql.VarChar(50),    settlementId)
      .input('ManagerId',      this.sql.VarChar(50),    settlement.managerId      ?? null)
      .input('ManagerName',    this.sql.NVarChar(255),  settlement.managerName    ?? null)
      .input('Status',         this.sql.NVarChar(50),   settlement.status         ?? null)
      .input('ApprovedDate',   this.sql.DateTime,       settlement.approvedDate   ?? null)
      .input('CompletedDate',  this.sql.DateTime,       settlement.completedDate  ?? null)
      .input('ManagerNotes',   this.sql.NVarChar(4000), settlement.managerNotes   ?? null)
      .input('UpdatedBy',      this.sql.VarChar(50),    settlement.updatedBy      ?? null)
      .input('UpdatedDate',    this.sql.DateTime,       settlement.updatedDate    ?? null)
      .execute('usp_UpdateCashBalanceSettlement');

    return this.findById(settlementId);
  }

  async delete(settlementId) {
    const pool = await this.db();

    await pool.request()
      .input('SettlementId', this.sql.VarChar(50), settlementId)
      .execute('usp_DeleteCashBalanceSettlement');
  }

  async generateNextId() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GenerateNextCashBalanceSettlementId');

    return result.recordset[0].NextSettlementId;
  }

  async getSettlementsSummary() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetCashBalanceSettlementsSummary');

    return result.recordset;
  }

  async getUserSettlementsSummary(userId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('UserId', this.sql.VarChar(50), userId)
      .execute('usp_GetUserCashBalanceSettlementsSummary');

    return result.recordset;
  }

  mapToEntity(row) {
    let relatedAssignments = [];
    if (row.relatedAssignments) {
      try { relatedAssignments = JSON.parse(row.relatedAssignments); }
      catch (e) { console.log('Error parsing relatedAssignments JSON:', e.message); }
    }

    const entity = new CashBalanceSettlement({
      settlementId:       row.settlementId,
      userId:             row.userId,
      userName:           row.userName,
      managerId:          row.managerId,
      managerName:        row.managerName,
      settlementType:     row.settlementType,
      amount:             row.amount,
      status:             row.status,
      requestDate:        row.requestDate,
      approvedDate:       row.approvedDate,
      completedDate:      row.completedDate,
      notes:              row.notes,
      managerNotes:       row.managerNotes,
      relatedAssignments,
      createdBy:          row.createdBy,
      createdDate:        row.createdDate,
      updatedBy:          row.updatedBy,
      updatedDate:        row.updatedDate,
    });
    entity.jobId        = row.jobId        || null;
    entity.cusdecNumber = row.cusdecNumber || null;
    return entity;
  }
}

module.exports = MSSQLCashBalanceSettlementRepository;
