/**
 * MSSQL ContactPerson Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const IContactPersonRepository = require('../../domain/repositories/IContactPersonRepository');
const ContactPerson = require('../../domain/entities/ContactPerson');

class MSSQLContactPersonRepository extends IContactPersonRepository {
  constructor(dbConnection, sql) {
    super();
    this.db = dbConnection;
    this.sql = sql;
  }

  async create(contactPerson) {
    const pool = await this.db();

    await pool.request()
      .input('ContactPersonId', this.sql.Int,         contactPerson.contactPersonId)
      .input('CustomerId',      this.sql.VarChar(50), contactPerson.customerId)
      .input('Name',            this.sql.VarChar(255), contactPerson.name)
      .input('Phone',           this.sql.VarChar(20),  contactPerson.phone)
      .input('Email',           this.sql.VarChar(255), contactPerson.email)
      .input('Designation',     this.sql.VarChar(100), contactPerson.designation)
      .execute('usp_CreateContactPerson');

    return contactPerson;
  }

  async findByCustomerId(customerId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('CustomerId', this.sql.VarChar(50), customerId)
      .execute('usp_GetContactPersonsByCustomer');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async deleteByCustomerId(customerId) {
    const pool = await this.db();

    await pool.request()
      .input('CustomerId', this.sql.VarChar(50), customerId)
      .execute('usp_DeleteContactPersonsByCustomer');

    return true;
  }

  mapToEntity(row) {
    return new ContactPerson({
      contactPersonId: row.ContactPersonId,
      customerId:      row.CustomerId,
      name:            row.Name,
      phone:           row.Phone,
      email:           row.Email,
      designation:     row.Designation,
    });
  }

  formatId(id) {
    return String(id).padStart(6, '0');
  }
}

module.exports = MSSQLContactPersonRepository;
