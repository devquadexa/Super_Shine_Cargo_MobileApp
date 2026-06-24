/**
 * MSSQL Office Pay Item Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const IOfficePayItemRepository = require('../../domain/repositories/IOfficePayItemRepository');
const OfficePayItem = require('../../domain/entities/OfficePayItem');

class MSSQLOfficePayItemRepository extends IOfficePayItemRepository {
  constructor(getConnection, sql) {
    super();
    this.db = getConnection;
    this.sql = sql;
  }

  async create(officePayItem) {
    try {
      console.log('MSSQLOfficePayItemRepository.create - START');
      const pool = await this.db();

      await pool.request()
        .input('OfficePayItemId', this.sql.VarChar(50),    officePayItem.officePayItemId)
        .input('JobId',           this.sql.VarChar(50),    officePayItem.jobId)
        .input('Description',     this.sql.NVarChar(500),  officePayItem.description)
        .input('ActualCost',      this.sql.Decimal(18, 2), officePayItem.actualCost)
        .input('PaidBy',          this.sql.VarChar(50),    officePayItem.paidBy)
        .input('HasBill',         this.sql.Bit,            officePayItem.hasBill || false)
        .execute('usp_CreateOfficePayItem');

      console.log('MSSQLOfficePayItemRepository.create - SUCCESS');
      return officePayItem;
    } catch (error) {
      console.error('MSSQLOfficePayItemRepository.create - ERROR:', error);
      throw error;
    }
  }

  async findById(officePayItemId) {
    try {
      const pool = await this.db();

      const result = await pool.request()
        .input('OfficePayItemId', this.sql.VarChar(50), officePayItemId)
        .execute('usp_GetOfficePayItemById');

      if (result.recordset.length === 0) return null;
      return new OfficePayItem(result.recordset[0]);
    } catch (error) {
      console.error('MSSQLOfficePayItemRepository.findById - ERROR:', error);
      throw error;
    }
  }

  async findByJobId(jobId) {
    try {
      console.log('MSSQLOfficePayItemRepository.findByJobId - jobId:', jobId);
      const pool = await this.db();

      const result = await pool.request()
        .input('JobId', this.sql.VarChar(50), jobId)
        .execute('usp_GetOfficePayItemsByJob');

      console.log('MSSQLOfficePayItemRepository.findByJobId - found items:', result.recordset.length);
      return result.recordset.map(row => new OfficePayItem(row));
    } catch (error) {
      console.error('MSSQLOfficePayItemRepository.findByJobId - ERROR:', error);
      throw error;
    }
  }

  async findAll() {
    try {
      const pool = await this.db();

      const result = await pool.request()
        .execute('usp_GetAllOfficePayItems');

      return result.recordset.map(row => new OfficePayItem(row));
    } catch (error) {
      console.error('MSSQLOfficePayItemRepository.findAll - ERROR:', error);
      throw error;
    }
  }

  async update(officePayItemId, updateData) {
    try {
      console.log('MSSQLOfficePayItemRepository.update - START');
      const pool = await this.db();

      await pool.request()
        .input('OfficePayItemId', this.sql.VarChar(50),    officePayItemId)
        .input('Description',     this.sql.NVarChar(500),  updateData.description   ?? null)
        .input('ActualCost',      this.sql.Decimal(18, 2), updateData.actualCost    ?? null)
        .input('BillingAmount',   this.sql.Decimal(18, 2), updateData.billingAmount ?? null)
        .input('HasBill',         this.sql.Bit,            updateData.hasBill       ?? null)
        .execute('usp_UpdateOfficePayItem');

      console.log('MSSQLOfficePayItemRepository.update - SUCCESS');
      return this.findById(officePayItemId);
    } catch (error) {
      console.error('MSSQLOfficePayItemRepository.update - ERROR:', error);
      throw error;
    }
  }

  async delete(officePayItemId) {
    try {
      const pool = await this.db();

      await pool.request()
        .input('OfficePayItemId', this.sql.VarChar(50), officePayItemId)
        .execute('usp_DeleteOfficePayItem');

      return true;
    } catch (error) {
      console.error('MSSQLOfficePayItemRepository.delete - ERROR:', error);
      throw error;
    }
  }

  async generateNextId() {
    try {
      const pool = await this.db();

      const result = await pool.request()
        .execute('usp_GenerateNextOfficePayItemId');

      return result.recordset[0].NextOfficePayItemId;
    } catch (error) {
      console.error('MSSQLOfficePayItemRepository.generateNextId - ERROR:', error);
      throw error;
    }
  }
}

module.exports = MSSQLOfficePayItemRepository;
