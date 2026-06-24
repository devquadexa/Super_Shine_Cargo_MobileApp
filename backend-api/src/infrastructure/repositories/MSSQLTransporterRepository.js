const ITransporterRepository = require('../../domain/repositories/ITransporterRepository');
const Transporter = require('../../domain/entities/Transporter');

class MSSQLTransporterRepository extends ITransporterRepository {
  constructor(dbConnection, sql) {
    super();
    this.db = dbConnection;
    this.sql = sql;
  }

  async create(transporter) {
    const pool = await this.db();

    await pool.request()
      .input('TransporterId',    this.sql.VarChar(50),    transporter.transporterId)
      .input('Name',             this.sql.NVarChar(200),  transporter.name)
      .input('Phone',            this.sql.VarChar(20),    transporter.mainPhone)
      .input('Email',            this.sql.VarChar(100),   transporter.email || null)
      .input('LorryNumber',      this.sql.NVarChar(100),  transporter.lorryNumber || null)
      .input('TransporterType',  this.sql.NVarChar(50),   transporter.transporterType || 'Non FCL')
      .input('DriverName',       this.sql.NVarChar(200),  transporter.driverName || null)
      .input('Size',             this.sql.NVarChar(100),  transporter.size || null)
      .input('RegistrationDate', this.sql.DateTime,       transporter.registrationDate)
      .input('AddressNumber',    this.sql.NVarChar(100),  transporter.addressNumber)
      .input('AddressStreet1',   this.sql.NVarChar(200),  transporter.addressStreet1)
      .input('AddressStreet2',   this.sql.NVarChar(200),  transporter.addressStreet2 || null)
      .input('AddressDistrict',  this.sql.NVarChar(100),  transporter.addressDistrict)
      .input('AddressCity',      this.sql.NVarChar(100),  transporter.addressCity)
      .input('AddressCountry',   this.sql.NVarChar(100),  transporter.addressCountry || 'Sri Lanka')
      .input('ContactPersonsJson', this.sql.NVarChar(4000), JSON.stringify(transporter.contactPersons || []))
      .input('ContactPerson',    this.sql.NVarChar(150),  transporter.contactPerson || transporter.contactPersons?.[0]?.name || null)
      .input('Address',          this.sql.NVarChar(500),  transporter.getFormattedAddress())
      .input('VehicleNumber',    this.sql.NVarChar(100),  transporter.vehicleNumber || null)
      .input('Notes',            this.sql.NVarChar(4000), transporter.notes || null)
      .input('CreatedDate',      this.sql.DateTime,       transporter.createdDate)
      .input('IsActive',         this.sql.Bit,            transporter.isActive)
      .execute('usp_CreateTransporter');

    return transporter;
  }

  async findById(transporterId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('TransporterId', this.sql.VarChar(50), transporterId)
      .execute('usp_GetTransporterById');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async findAll(filters = {}) {
    const pool = await this.db();

    const result = await pool.request()
      .input('Name', this.sql.NVarChar(200), filters.name || null)
      .execute('usp_GetAllTransporters');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async update(transporterId, transporter) {
    const pool = await this.db();

    await pool.request()
      .input('TransporterId',    this.sql.VarChar(50),    transporterId)
      .input('Name',             this.sql.NVarChar(200),  transporter.name)
      .input('Phone',            this.sql.VarChar(20),    transporter.mainPhone)
      .input('Email',            this.sql.VarChar(100),   transporter.email || null)
      .input('LorryNumber',      this.sql.NVarChar(100),  transporter.lorryNumber || null)
      .input('TransporterType',  this.sql.NVarChar(50),   transporter.transporterType || 'Non FCL')
      .input('DriverName',       this.sql.NVarChar(200),  transporter.driverName || null)
      .input('Size',             this.sql.NVarChar(100),  transporter.size || null)
      .input('RegistrationDate', this.sql.DateTime,       transporter.registrationDate)
      .input('AddressNumber',    this.sql.NVarChar(100),  transporter.addressNumber)
      .input('AddressStreet1',   this.sql.NVarChar(200),  transporter.addressStreet1)
      .input('AddressStreet2',   this.sql.NVarChar(200),  transporter.addressStreet2 || null)
      .input('AddressDistrict',  this.sql.NVarChar(100),  transporter.addressDistrict)
      .input('AddressCity',      this.sql.NVarChar(100),  transporter.addressCity)
      .input('AddressCountry',   this.sql.NVarChar(100),  transporter.addressCountry || 'Sri Lanka')
      .input('ContactPersonsJson', this.sql.NVarChar(4000), JSON.stringify(transporter.contactPersons || []))
      .input('ContactPerson',    this.sql.NVarChar(150),  transporter.contactPerson || transporter.contactPersons?.[0]?.name || null)
      .input('Address',          this.sql.NVarChar(500),  transporter.getFormattedAddress())
      .input('VehicleNumber',    this.sql.NVarChar(100),  transporter.vehicleNumber || null)
      .input('Notes',            this.sql.NVarChar(4000), transporter.notes || null)
      .input('IsActive',         this.sql.Bit,            transporter.isActive !== undefined ? transporter.isActive : true)
      .execute('usp_UpdateTransporter');

    return transporter;
  }

  async delete(transporterId) {
    const pool = await this.db();

    await pool.request()
      .input('TransporterId', this.sql.VarChar(50), transporterId)
      .execute('usp_DeleteTransporter');

    return true;
  }

  async exists(transporterId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('TransporterId', this.sql.VarChar(50), transporterId)
      .execute('usp_TransporterExists');

    return result.recordset[0].Count > 0;
  }

  async findByEmail(email) {
    const pool = await this.db();

    const result = await pool.request()
      .input('Email', this.sql.VarChar(100), email)
      .execute('usp_GetTransporterByEmail');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async findByName(name) {
    const pool = await this.db();

    const result = await pool.request()
      .input('Name', this.sql.NVarChar(200), name)
      .execute('usp_GetTransporterByName');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async generateNextId() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GenerateNextTransporterId');

    return result.recordset[0].NextTransporterId;
  }

  mapToEntity(row) {
    let contactPersons = [];
    if (row.contactPersonsJson) {
      try {
        contactPersons = JSON.parse(row.contactPersonsJson);
      } catch {
        contactPersons = [];
      }
    }

    return new Transporter({
      transporterId:   row.transporterId,
      name:            row.name,
      mainPhone:       row.phone,
      contactPerson:   row.contactPerson,
      email:           row.email,
      lorryNumber:     row.lorryNumber,
      transporterType: row.transporterType || 'Non FCL',
      driverName:      row.driverName,
      size:            row.size,
      registrationDate: row.registrationDate,
      addressNumber:   row.addressNumber,
      addressStreet1:  row.addressStreet1,
      addressStreet2:  row.addressStreet2,
      addressDistrict: row.addressDistrict,
      addressCity:     row.addressCity,
      addressCountry:  row.addressCountry,
      contactPersons,
      address:         row.address,
      vehicleNumber:   row.vehicleNumber,
      notes:           row.notes,
      createdDate:     row.createdDate,
      isActive:        row.isActive,
    });
  }
}

module.exports = MSSQLTransporterRepository;
