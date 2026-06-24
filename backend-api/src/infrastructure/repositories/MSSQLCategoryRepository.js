/**
 * MSSQL Category Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const ICategoryRepository = require('../../domain/repositories/ICategoryRepository');
const Category = require('../../domain/entities/Category');

class MSSQLCategoryRepository extends ICategoryRepository {
  constructor(dbConnection, sql) {
    super();
    this.db = dbConnection;
    this.sql = sql;
  }

  async findAll() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetAllCategories');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findById(categoryId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('CategoryId', this.sql.Int, categoryId)
      .execute('usp_GetCategoryById');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async findByCustomerId(customerId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('CustomerId', this.sql.VarChar(50), customerId)
      .execute('usp_GetCategoriesByCustomer');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async assignToCustomer(customerId, categoryIds) {
    const pool = await this.db();

    await this.removeFromCustomer(customerId);

    for (const categoryId of categoryIds) {
      await pool.request()
        .input('CustomerId', this.sql.VarChar(50), customerId)
        .input('CategoryId', this.sql.Int,          categoryId)
        .execute('usp_AssignCategoryToCustomer');
    }

    return true;
  }

  async removeFromCustomer(customerId) {
    const pool = await this.db();

    await pool.request()
      .input('CustomerId', this.sql.VarChar(50), customerId)
      .execute('usp_RemoveCategoriesFromCustomer');

    return true;
  }

  mapToEntity(row) {
    return new Category({
      categoryId:   row.CategoryId,
      categoryName: row.CategoryName,
    });
  }

  formatId(id) {
    return String(id).padStart(6, '0');
  }
}

module.exports = MSSQLCategoryRepository;
