/**
 * MSSQL Customer Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const ICustomerRepository = require('../../domain/repositories/ICustomerRepository');
const Customer = require('../../domain/entities/Customer');

class MSSQLCustomerRepository extends ICustomerRepository {
  constructor(dbConnection, sql, contactPersonRepository, categoryRepository) {
    super();
    this.db = dbConnection;
    this.sql = sql;
    this.contactPersonRepository = contactPersonRepository;
    this.categoryRepository = categoryRepository;
  }

  async create(customer) {
    const pool = await this.db();

    await pool.request()
      .input('CustomerId',            this.sql.VarChar(50),  customer.customerId)
      .input('Name',                  this.sql.VarChar(255), customer.name)
      .input('MainPhone',             this.sql.VarChar(20),  customer.mainPhone)
      .input('Email',                 this.sql.VarChar(255), customer.email)
      .input('AddressNumber',         this.sql.VarChar(100), customer.addressNumber)
      .input('AddressStreet1',        this.sql.VarChar(200), customer.addressStreet1)
      .input('AddressStreet2',        this.sql.VarChar(200), customer.addressStreet2)
      .input('AddressDistrict',       this.sql.VarChar(100), customer.addressDistrict)
      .input('AddressCity',           this.sql.VarChar(100), customer.addressCity)
      .input('AddressCountry',        this.sql.VarChar(100), customer.addressCountry || 'Sri Lanka')
      .input('OfficeAddressNumber',   this.sql.VarChar(100), customer.officeAddressNumber)
      .input('OfficeAddressStreet1',  this.sql.VarChar(200), customer.officeAddressStreet1)
      .input('OfficeAddressStreet2',  this.sql.VarChar(200), customer.officeAddressStreet2)
      .input('OfficeAddressDistrict', this.sql.VarChar(100), customer.officeAddressDistrict)
      .input('OfficeAddressCity',     this.sql.VarChar(100), customer.officeAddressCity)
      .input('OfficeAddressCountry',  this.sql.VarChar(100), customer.officeAddressCountry || 'Sri Lanka')
      .input('IsOfficeAddressSame',   this.sql.Bit,          customer.isOfficeAddressSame)
      .input('Website',               this.sql.VarChar(255), customer.website || null)
      .input('RegistrationDate',      this.sql.DateTime,     customer.registrationDate)
      .input('CreditPeriodDays',      this.sql.Int,          customer.creditPeriodDays || 30)
      .input('IsActive',              this.sql.Bit,          customer.isActive)
      .execute('usp_CreateCustomer');

    if (customer.contactPersons?.length > 0) {
      const ContactPerson = require('../../domain/entities/ContactPerson');
      for (let i = 0; i < customer.contactPersons.length; i++) {
        const cp = customer.contactPersons[i];
        await this.contactPersonRepository.create(new ContactPerson({
          contactPersonId: i + 1,
          customerId: customer.customerId,
          name: cp.name, phone: cp.phone,
          email: cp.email || null, designation: cp.designation || null,
        }));
      }
    }

    if (customer.categories?.length > 0) {
      await this.categoryRepository.assignToCustomer(customer.customerId, customer.categories);
    }

    return customer;
  }

  async findById(customerId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('CustomerId', this.sql.VarChar(50), customerId)
      .execute('usp_GetCustomerById');

    if (result.recordset.length === 0) return null;

    const customer = this.mapToEntity(result.recordset[0]);
    customer.contactPersons = await this.contactPersonRepository.findByCustomerId(customerId);
    customer.categories     = await this.categoryRepository.findByCustomerId(customerId);

    return customer;
  }

  async findAll(filters = {}) {
    const pool = await this.db();

    const result = await pool.request()
      .input('Name', this.sql.VarChar(255), filters.name || null)
      .execute('usp_GetAllCustomers');

    const customers = [];
    for (const row of result.recordset) {
      const customer = this.mapToEntity(row);
      customer.contactPersons = await this.contactPersonRepository.findByCustomerId(customer.customerId);
      customer.categories     = await this.categoryRepository.findByCustomerId(customer.customerId);
      customers.push(customer);
    }

    return customers;
  }

  async update(customerId, customer) {
    const pool = await this.db();

    await pool.request()
      .input('CustomerId',            this.sql.VarChar(50),  customerId)
      .input('Name',                  this.sql.VarChar(255), customer.name)
      .input('MainPhone',             this.sql.VarChar(20),  customer.mainPhone)
      .input('Email',                 this.sql.VarChar(255), customer.email)
      .input('AddressNumber',         this.sql.VarChar(100), customer.addressNumber)
      .input('AddressStreet1',        this.sql.VarChar(200), customer.addressStreet1)
      .input('AddressStreet2',        this.sql.VarChar(200), customer.addressStreet2)
      .input('AddressDistrict',       this.sql.VarChar(100), customer.addressDistrict)
      .input('AddressCity',           this.sql.VarChar(100), customer.addressCity)
      .input('AddressCountry',        this.sql.VarChar(100), customer.addressCountry || 'Sri Lanka')
      .input('OfficeAddressNumber',   this.sql.VarChar(100), customer.officeAddressNumber)
      .input('OfficeAddressStreet1',  this.sql.VarChar(200), customer.officeAddressStreet1)
      .input('OfficeAddressStreet2',  this.sql.VarChar(200), customer.officeAddressStreet2)
      .input('OfficeAddressDistrict', this.sql.VarChar(100), customer.officeAddressDistrict)
      .input('OfficeAddressCity',     this.sql.VarChar(100), customer.officeAddressCity)
      .input('OfficeAddressCountry',  this.sql.VarChar(100), customer.officeAddressCountry || 'Sri Lanka')
      .input('IsOfficeAddressSame',   this.sql.Bit,          customer.isOfficeAddressSame)
      .input('Website',               this.sql.VarChar(255), customer.website || null)
      .input('CreditPeriodDays',      this.sql.Int,          customer.creditPeriodDays || 30)
      .input('IsActive',              this.sql.Bit,          customer.isActive !== undefined ? customer.isActive : true)
      .execute('usp_UpdateCustomer');

    await this.contactPersonRepository.deleteByCustomerId(customerId);
    if (customer.contactPersons?.length > 0) {
      const ContactPerson = require('../../domain/entities/ContactPerson');
      for (let i = 0; i < customer.contactPersons.length; i++) {
        const cp = customer.contactPersons[i];
        await this.contactPersonRepository.create(new ContactPerson({
          contactPersonId: i + 1,
          customerId,
          name: cp.name, phone: cp.phone,
          email: cp.email || null, designation: cp.designation || null,
        }));
      }
    }

    if (customer.categories?.length > 0) {
      await this.categoryRepository.assignToCustomer(customerId, customer.categories);
    } else {
      await this.categoryRepository.removeFromCustomer(customerId);
    }

    return customer;
  }

  async delete(customerId) {
    const pool = await this.db();

    await pool.request()
      .input('CustomerId', this.sql.VarChar(50), customerId)
      .execute('usp_DeleteCustomer');

    return true;
  }

  async exists(customerId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('CustomerId', this.sql.VarChar(50), customerId)
      .execute('usp_CustomerExists');

    return result.recordset[0].count > 0;
  }

  async findByEmail(email) {
    const pool = await this.db();

    const result = await pool.request()
      .input('Email', this.sql.VarChar(255), email)
      .execute('usp_GetCustomerByEmail');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async generateNextId() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GenerateNextCustomerId');

    return result.recordset[0].NextCustomerId;
  }

  mapToEntity(row) {
    return new Customer({
      customerId:           row.CustomerId,
      name:                 row.Name,
      mainPhone:            row.MainPhone,
      email:                row.Email,
      addressNumber:        row.addressNumber,
      addressStreet1:       row.addressStreet1,
      addressStreet2:       row.addressStreet2,
      addressDistrict:      row.addressDistrict,
      addressCity:          row.addressCity,
      addressCountry:       row.addressCountry       || 'Sri Lanka',
      officeAddressNumber:  row.officeAddressNumber,
      officeAddressStreet1: row.officeAddressStreet1,
      officeAddressStreet2: row.officeAddressStreet2,
      officeAddressDistrict:row.officeAddressDistrict,
      officeAddressCity:    row.officeAddressCity,
      officeAddressCountry: row.officeAddressCountry || 'Sri Lanka',
      isOfficeAddressSame:  row.isOfficeAddressSame,
      website:              row.Website,
      registrationDate:     row.RegistrationDate,
      creditPeriodDays:     row.creditPeriodDays     || 30,
      isActive:             row.IsActive,
    });
  }
}

module.exports = MSSQLCustomerRepository;
