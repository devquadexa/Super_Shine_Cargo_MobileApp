/**
 * MSSQL Other Expense Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const IOtherExpenseRepository = require('../../domain/repositories/IOtherExpenseRepository');
const OtherExpense = require('../../domain/entities/OtherExpense');

class MSSQLOtherExpenseRepository extends IOtherExpenseRepository {
  constructor(dbConnection, sql) {
    super();
    this.db = dbConnection;
    this.sql = sql;
  }

  async create(expense) {
    const pool = await this.db();

    await pool.request()
      .input('ExpenseId',       this.sql.VarChar(50),    expense.expenseId)
      .input('Category',        this.sql.NVarChar(100),  expense.category)
      .input('Description',     this.sql.NVarChar(500),  expense.description)
      .input('Amount',          this.sql.Decimal(18, 2), expense.amount)
      .input('ExpenseDate',     this.sql.Date,           expense.expenseDate)
      .input('PaymentMethod',   this.sql.NVarChar(50),   expense.paymentMethod  || null)
      .input('ReferenceNumber', this.sql.NVarChar(100),  expense.referenceNumber || null)
      .input('Notes',           this.sql.NVarChar(4000), expense.notes          || null)
      .input('RecordedBy',      this.sql.VarChar(50),    expense.recordedBy)
      .input('CreatedDate',     this.sql.DateTime,       expense.createdDate)
      .input('AttachmentUrl',   this.sql.NVarChar(500),  expense.attachmentUrl  || null)
      .execute('usp_CreateOtherExpense');

    return expense;
  }

  async findById(expenseId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('ExpenseId', this.sql.VarChar(50), expenseId)
      .execute('usp_GetOtherExpenseById');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async findAll(filters = {}) {
    const pool = await this.db();

    const result = await pool.request()
      .input('Category', this.sql.NVarChar(100), filters.category || null)
      .input('FromDate', this.sql.Date,          filters.fromDate || null)
      .input('ToDate',   this.sql.Date,          filters.toDate   || null)
      .execute('usp_GetAllOtherExpenses');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByDateRange(fromDate, toDate, category = null) {
    const pool = await this.db();

    const result = await pool.request()
      .input('FromDate', this.sql.Date,         fromDate)
      .input('ToDate',   this.sql.Date,         toDate)
      .input('Category', this.sql.NVarChar(100), category || null)
      .execute('usp_GetOtherExpensesByDateRange');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async update(expenseId, expense) {
    const pool = await this.db();

    await pool.request()
      .input('ExpenseId',       this.sql.VarChar(50),    expenseId)
      .input('Category',        this.sql.NVarChar(100),  expense.category)
      .input('Description',     this.sql.NVarChar(500),  expense.description)
      .input('Amount',          this.sql.Decimal(18, 2), expense.amount)
      .input('ExpenseDate',     this.sql.Date,           expense.expenseDate)
      .input('PaymentMethod',   this.sql.NVarChar(50),   expense.paymentMethod   || null)
      .input('ReferenceNumber', this.sql.NVarChar(100),  expense.referenceNumber || null)
      .input('Notes',           this.sql.NVarChar(4000), expense.notes           || null)
      .input('AttachmentUrl',   this.sql.NVarChar(500),  expense.attachmentUrl   || null)
      .execute('usp_UpdateOtherExpense');

    return this.findById(expenseId);
  }

  async delete(expenseId) {
    const pool = await this.db();

    await pool.request()
      .input('ExpenseId', this.sql.VarChar(50), expenseId)
      .execute('usp_DeleteOtherExpense');

    return true;
  }

  async generateNextId() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GenerateNextOtherExpenseId');

    return result.recordset[0].NextExpenseId;
  }

  async getCategories() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetOtherExpenseCategories');

    return result.recordset.map(row => row.category);
  }

  async getSummaryByCategory(fromDate, toDate) {
    const pool = await this.db();

    const result = await pool.request()
      .input('FromDate', this.sql.Date, fromDate)
      .input('ToDate',   this.sql.Date, toDate)
      .execute('usp_GetOtherExpenseSummaryByCategory');

    return result.recordset.map(row => ({
      category:    row.category,
      count:       row.count,
      totalAmount: parseFloat(row.totalAmount) || 0,
    }));
  }

  mapToEntity(row) {
    return new OtherExpense({
      expenseId:       row.expenseId,
      category:        row.category,
      description:     row.description,
      amount:          parseFloat(row.amount) || 0,
      expenseDate:     row.expenseDate,
      paymentMethod:   row.paymentMethod,
      referenceNumber: row.referenceNumber,
      notes:           row.notes,
      recordedBy:      row.recordedBy,
      recordedByName:  row.recordedByName,
      createdDate:     row.createdDate,
      attachmentUrl:   row.attachmentUrl,
    });
  }
}

module.exports = MSSQLOtherExpenseRepository;
