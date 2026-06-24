/**
 * MSSQL Job Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const IJobRepository = require('../../domain/repositories/IJobRepository');
const Job = require('../../domain/entities/Job');

class MSSQLJobRepository extends IJobRepository {
  constructor(dbConnection, sql) {
    super();
    this.db = dbConnection;
    this.sql = sql;
  }

  async create(job) {
    const pool = await this.db();
    console.log('MSSQLJobRepository.create - job:', job);

    await pool.request()
      .input('JobId',                 this.sql.VarChar(50),   job.jobId)
      .input('CustomerId',            this.sql.VarChar(50),   job.customerId)
      .input('BLNumber',              this.sql.VarChar(100),  job.blNumber)
      .input('CUSDECNumber',          this.sql.VarChar(100),  job.cusdecNumber)
      .input('CUSDECDate',            this.sql.Date,          job.cusdecDate)
      .input('OpenDate',              this.sql.Date,          job.openDate)
      .input('ShipmentCategory',      this.sql.VarChar(100),  job.shipmentCategory)
      .input('ChassisNumber',         this.sql.VarChar(100),  job.chassisNumber)
      .input('Exporter',              this.sql.VarChar(200),  job.exporter)
      .input('Transporter',           this.sql.VarChar(200),  job.transporter)
      .input('LCNumber',              this.sql.VarChar(100),  job.lcNumber)
      .input('ContainerNumber',       this.sql.VarChar(100),  job.containerNumber)
      .input('TransportDeliveryDate', this.sql.Date,          job.transportDeliveryDate)
      .input('Status',                this.sql.VarChar(50),   job.status)
      .input('AssignedTo',            this.sql.VarChar(50),   job.assignedTo)
      .input('CreatedDate',           this.sql.DateTime,      job.createdDate)
      .execute('usp_CreateJob');

    console.log('MSSQLJobRepository.create - job created successfully');
    return job;
  }

  async findById(jobId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('JobId', this.sql.VarChar(50), jobId)
      .execute('usp_GetJobById');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async findAll(filters = {}) {
    if (filters.assignedTo) {
      return this.findByAssignedUser(filters.assignedTo);
    }

    const pool = await this.db();

    const result = await pool.request()
      .input('Status',     this.sql.VarChar(50), filters.status     || null)
      .input('CustomerId', this.sql.VarChar(50), filters.customerId || null)
      .execute('usp_GetAllJobs');

    return Promise.all(result.recordset.map(row => this.mapToEntity(row)));
  }

  async findByAssignedUser(userId) {
    const pool = await this.db();
    try {
      console.log('findByAssignedUser called with userId:', userId);

      const result = await pool.request()
        .input('UserId', this.sql.VarChar(50), userId)
        .execute('usp_GetJobsByAssignedUser');

      console.log('Jobs found for user:', result.recordset.length);
      return Promise.all(result.recordset.map(row => this.mapToEntity(row)));
    } catch (error) {
      console.error('Error in findByAssignedUser:', error);
      throw error;
    }
  }

  async findByCustomer(customerId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('CustomerId', this.sql.VarChar(50), customerId)
      .execute('usp_GetJobsByCustomer');

    return Promise.all(result.recordset.map(row => this.mapToEntity(row)));
  }

  async update(jobId, job) {
    const pool = await this.db();

    await pool.request()
      .input('JobId',                 this.sql.VarChar(50),  jobId)
      .input('BLNumber',              this.sql.VarChar(100), job.blNumber)
      .input('CUSDECNumber',          this.sql.VarChar(100), job.cusdecNumber)
      .input('CUSDECDate',            this.sql.Date,         job.cusdecDate)
      .input('OpenDate',              this.sql.Date,         job.openDate)
      .input('ShipmentCategory',      this.sql.VarChar(100), job.shipmentCategory)
      .input('ChassisNumber',         this.sql.VarChar(100), job.chassisNumber)
      .input('Exporter',              this.sql.VarChar(200), job.exporter)
      .input('Transporter',           this.sql.VarChar(200), job.transporter)
      .input('LCNumber',              this.sql.VarChar(100), job.lcNumber)
      .input('ContainerNumber',       this.sql.VarChar(100), job.containerNumber)
      .input('TransportDeliveryDate', this.sql.Date,         job.transportDeliveryDate)
      .input('Status',                this.sql.VarChar(50),  job.status)
      .input('AssignedTo',            this.sql.VarChar(50),  job.assignedTo)
      .execute('usp_UpdateJob');

    return job;
  }

  async syncAdvancePaymentAggregate(jobId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('JobId', this.sql.VarChar(50), jobId)
      .execute('usp_SyncJobAdvancePaymentAggregate');

    const row = result.recordset[0];
    return {
      totalAdvancePayment:  parseFloat(row.totalAdvancePayment || 0),
      latestPaymentDate:    row.latestPaymentDate   || null,
      latestPaymentType:    row.latestPaymentType   || null,
      latestCheckNo:        row.latestCheckNo       || null,
      latestNotes:          row.latestNotes         || null,
      latestRecordedBy:     row.latestRecordedBy    || null,
    };
  }

  async addAdvancePayment(jobId, advancePayment, paymentDate, paymentType, checkNo, notes, recordedByUserId) {
    const pool = await this.db();

    const amount = parseFloat(advancePayment) || 0;
    if (amount <= 0) throw new Error('Advance payment amount must be greater than 0');

    const advanceDate      = paymentDate ? new Date(paymentDate) : new Date();
    const finalPaymentType = paymentType || null;
    const finalCheckNo     = paymentType === 'check' ? checkNo : null;

    // Backward compatibility: migrate legacy aggregate row to payment entry if no entries exist yet
    const countResult = await pool.request()
      .input('JobId', this.sql.VarChar(50), jobId)
      .execute('usp_CountJobAdvancePayments');

    if (countResult.recordset[0].paymentCount === 0) {
      const legacyResult = await pool.request()
        .input('JobId', this.sql.VarChar(50), jobId)
        .execute('usp_GetJobAdvancePaymentLegacyFields');

      const legacy       = legacyResult.recordset[0];
      const legacyAmount = parseFloat(legacy?.advancePayment || 0);

      if (legacyAmount > 0) {
        await pool.request()
          .input('JobId',           this.sql.VarChar(50),   jobId)
          .input('Amount',          this.sql.Decimal(18,2), legacyAmount)
          .input('PaymentMadeDate', this.sql.DateTime,      legacy.advancePaymentDate || new Date())
          .input('PaymentType',     this.sql.VarChar(50),   legacy.advancePaymentType || null)
          .input('CheckNo',         this.sql.VarChar(100),  legacy.advancePaymentCheckNo || null)
          .input('Notes',           this.sql.VarChar(4000), legacy.advancePaymentNotes || 'Legacy advance payment')
          .input('RecordedBy',      this.sql.VarChar(50),   legacy.advancePaymentRecordedBy || null)
          .execute('usp_InsertJobAdvancePayment');
      }
    }

    await pool.request()
      .input('JobId',           this.sql.VarChar(50),   jobId)
      .input('Amount',          this.sql.Decimal(18,2), amount)
      .input('PaymentMadeDate', this.sql.DateTime,      advanceDate)
      .input('PaymentType',     this.sql.VarChar(50),   finalPaymentType)
      .input('CheckNo',         this.sql.VarChar(100),  finalCheckNo)
      .input('Notes',           this.sql.VarChar(4000), notes || null)
      .input('RecordedBy',      this.sql.VarChar(50),   recordedByUserId)
      .execute('usp_InsertJobAdvancePayment');

    await this.syncAdvancePaymentAggregate(jobId);

    const createdResult = await pool.request()
      .input('JobId', this.sql.VarChar(50), jobId)
      .execute('usp_GetLatestJobAdvancePayment');

    const row = createdResult.recordset[0];
    return {
      advancePaymentId: row.advancePaymentId,
      jobId:            row.jobId,
      amount:           parseFloat(row.amount),
      paymentMadeDate:  row.paymentMadeDate,
      paymentType:      row.paymentType,
      checkNo:          row.checkNo,
      notes:            row.notes,
      recordedBy:       row.recordedBy,
      recordedDate:     row.recordedDate,
    };
  }

  async getAdvancePaymentsByJob(jobId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('JobId', this.sql.VarChar(50), jobId)
      .execute('usp_GetJobAdvancePaymentsByJob');

    return result.recordset.map(row => ({
      advancePaymentId: row.advancePaymentId,
      jobId:            row.jobId,
      amount:           parseFloat(row.amount),
      paymentMadeDate:  row.paymentMadeDate,
      paymentType:      row.paymentType,
      checkNo:          row.checkNo,
      notes:            row.notes,
      recordedBy:       row.recordedBy,
      recordedByName:   row.recordedByName,
      recordedDate:     row.recordedDate,
    }));
  }

  async updateAdvancePaymentEntry(jobId, paymentId, amount, paymentDate, paymentType, checkNo, notes) {
    const pool = await this.db();

    const parsedAmount = parseFloat(amount) || 0;
    if (parsedAmount <= 0) throw new Error('Advance payment amount must be greater than 0');

    const paymentIdInt = parseInt(paymentId, 10);
    if (Number.isNaN(paymentIdInt)) throw new Error('Invalid advance payment record id');

    const result = await pool.request()
      .input('JobId',           this.sql.VarChar(50),   jobId)
      .input('PaymentId',       this.sql.Int,           paymentIdInt)
      .input('Amount',          this.sql.Decimal(18,2), parsedAmount)
      .input('PaymentMadeDate', this.sql.DateTime,      paymentDate ? new Date(paymentDate) : new Date())
      .input('PaymentType',     this.sql.VarChar(50),   paymentType || null)
      .input('CheckNo',         this.sql.VarChar(100),  paymentType === 'check' ? (checkNo || null) : null)
      .input('Notes',           this.sql.VarChar(4000), notes || null)
      .execute('usp_UpdateJobAdvancePaymentEntry');

    if (!result.rowsAffected || result.rowsAffected[0] === 0) {
      throw new Error('Advance payment record not found for this job');
    }

    await this.syncAdvancePaymentAggregate(jobId);

    const updatedResult = await pool.request()
      .input('JobId',     this.sql.VarChar(50), jobId)
      .input('PaymentId', this.sql.Int,         paymentIdInt)
      .execute('usp_GetJobAdvancePaymentById');

    const row = updatedResult.recordset[0];
    return {
      advancePaymentId: row.advancePaymentId,
      jobId:            row.jobId,
      amount:           parseFloat(row.amount),
      paymentMadeDate:  row.paymentMadeDate,
      paymentType:      row.paymentType,
      checkNo:          row.checkNo,
      notes:            row.notes,
      recordedBy:       row.recordedBy,
      recordedByName:   row.recordedByName,
      recordedDate:     row.recordedDate,
    };
  }

  async deleteAdvancePaymentEntry(jobId, paymentId) {
    const pool = await this.db();

    const paymentIdInt = parseInt(paymentId, 10);
    if (Number.isNaN(paymentIdInt)) throw new Error('Invalid advance payment record id');

    const result = await pool.request()
      .input('JobId',     this.sql.VarChar(50), jobId)
      .input('PaymentId', this.sql.Int,         paymentIdInt)
      .execute('usp_DeleteJobAdvancePaymentEntry');

    if (!result.rowsAffected || result.rowsAffected[0] === 0) {
      throw new Error('Advance payment record not found for this job');
    }

    await this.syncAdvancePaymentAggregate(jobId);
    return true;
  }

  async updateAdvancePayment(jobId, advancePayment, paymentDate, paymentType, checkNo, notes, recordedByUserId) {
    return this.addAdvancePayment(jobId, advancePayment, paymentDate, paymentType, checkNo, notes, recordedByUserId);
  }

  async updateStatus(jobId, status) {
    const pool = await this.db();

    await pool.request()
      .input('JobId',  this.sql.VarChar(50), jobId)
      .input('Status', this.sql.VarChar(50), status)
      .execute('usp_UpdateJobStatus');

    return true;
  }

  async assignToUser(jobId, userId) {
    const pool = await this.db();

    await pool.request()
      .input('JobId',  this.sql.VarChar(50), jobId)
      .input('UserId', this.sql.VarChar(50), userId)
      .execute('usp_AssignJobToUser');

    return true;
  }

  async delete(jobId) {
    const pool = await this.db();

    await pool.request()
      .input('JobId', this.sql.VarChar(50), jobId)
      .execute('usp_DeleteJob');

    return true;
  }

  async generateNextId() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GenerateNextJobId');

    return result.recordset[0].NextJobId;
  }

  async addPayItem(jobId, payItem) {
    const pool = await this.db();

    await pool.request()
      .input('PayItemId',     this.sql.VarChar(50),   payItem.payItemId)
      .input('JobId',         this.sql.VarChar(50),   jobId)
      .input('Description',   this.sql.VarChar(500),  payItem.description)
      .input('ActualCost',    this.sql.Decimal(10,2), payItem.amount)
      .input('BillingAmount', this.sql.Decimal(10,2), payItem.billingAmount || payItem.amount)
      .input('AddedBy',       this.sql.VarChar(50),   payItem.addedBy)
      .execute('usp_AddPayItem');

    return true;
  }

  async replacePayItems(jobId, payItems, userId) {
    const pool = await this.db();
    try {
      console.log('=== REPLACE PAY ITEMS START ===');

      // Store JSON in Jobs table
      await pool.request()
        .input('JobId',    this.sql.VarChar(50),   jobId)
        .input('PayItems', this.sql.NVarChar(4000), JSON.stringify(payItems))
        .execute('usp_UpdateJobPayItemsJson');

      // Also sync to PayItems table if it exists
      try {
        const transaction = new this.sql.Transaction(pool);
        await transaction.begin();

        await transaction.request()
          .input('JobId', this.sql.VarChar(50), jobId)
          .execute('usp_DeletePayItemsByJob');

        for (const item of payItems) {
          const payItemId = `PI${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
          await transaction.request()
            .input('PayItemId',     this.sql.VarChar(50),   payItemId)
            .input('JobId',         this.sql.VarChar(50),   jobId)
            .input('Description',   this.sql.VarChar(500),  item.description)
            .input('ActualCost',    this.sql.Decimal(10,2), item.amount || item.actualCost || 0)
            .input('BillingAmount', this.sql.Decimal(10,2), item.billingAmount || item.amount || 0)
            .input('AddedBy',       this.sql.VarChar(50),   userId)
            .execute('usp_AddPayItem');
        }

        await transaction.commit();
        console.log('✓ Pay items also stored in PayItems table');
      } catch (tableError) {
        console.log('⚠ Could not store in PayItems table:', tableError.message);
      }

      console.log('=== REPLACE PAY ITEMS END ===');
      return true;
    } catch (error) {
      console.error('❌ Error in replacePayItems:', error);
      throw error;
    }
  }

  async getPayItems(jobId) {
    const pool = await this.db();
    try {
      console.log('=== GET PAY ITEMS START ===');

      // Try JSON column first
      const jobResult = await pool.request()
        .input('JobId', this.sql.VarChar(50), jobId)
        .execute('usp_GetJobPayItemsJson');

      if (jobResult.recordset.length > 0) {
        const raw = jobResult.recordset[0].payItems;
        if (raw) {
          try {
            const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
            if (Array.isArray(parsed) && parsed.length > 0) {
              console.log('✅ Returning pay items from Jobs JSON column');
              return parsed;
            }
          } catch (e) {
            console.log('❌ Error parsing payItems JSON:', e.message);
          }
        }
      }

      // Fallback: PayItems table
      try {
        const result = await pool.request()
          .input('JobId', this.sql.VarChar(50), jobId)
          .execute('usp_GetPayItemsByJob');

        const payItems = result.recordset.map(row => ({
          id:            row.PayItemId,
          description:   row.Description,
          actualCost:    row.ActualCost   || 0,
          billingAmount: row.BillingAmount || 0,
          amount:        row.ActualCost   || 0,
          addedBy:       row.AddedBy,
          addedDate:     row.AddedDate,
        }));

        if (payItems.length > 0) {
          console.log('✅ Returning pay items from PayItems table');
          return payItems;
        }
      } catch (e) {
        console.log('❌ PayItems table error:', e.message);
      }

      return [];
    } catch (error) {
      console.log('❌ Error fetching pay items:', error.message);
      return [];
    }
  }

  async mapToEntity(row) {
    console.log('mapToEntity called with row:', row);

    const pool = await this.db();
    const jobId = row.jobId || row.JobId;

    // Pay items
    const payItems = await this.getPayItems(jobId);

    // Office pay items
    let officePayItems = [];
    try {
      const opiResult = await pool.request()
        .input('JobId', this.sql.VarChar(50), jobId)
        .execute('usp_GetOfficePayItemsByJob');

      officePayItems = opiResult.recordset.map(item => ({
        officePayItemId: item.officePayItemId,
        description:     item.description,
        actualCost:      parseFloat(item.actualCost) || 0,
        billingAmount:   item.billingAmount ? parseFloat(item.billingAmount) : null,
        paidBy:          item.paidBy,
        paidByName:      item.paidByName,
        paymentDate:     item.paymentDate,
        notes:           item.notes,
      }));
    } catch (e) {
      console.log('Could not fetch office pay items:', e.message);
    }

    // Fallback to JSON column if table returned nothing
    if (officePayItems.length === 0) {
      try {
        if (row.officePayItems && typeof row.officePayItems === 'string') {
          officePayItems = JSON.parse(row.officePayItems);
        } else if (Array.isArray(row.officePayItems)) {
          officePayItems = row.officePayItems;
        }
      } catch (e) {
        console.log('Could not parse officePayItems JSON:', e.message);
      }
    }

    // Assigned users
    let assignedUsers = [];
    try {
      const auResult = await pool.request()
        .input('JobId', this.sql.VarChar(50), jobId)
        .execute('usp_GetJobAssignedUsers');

      assignedUsers = auResult.recordset.map(a => ({ userId: a.userId, userName: a.userName }));
    } catch (e) {
      console.log('Could not fetch assigned users:', e.message);
    }

    // Metadata
    let metadataFromJson = {};
    try {
      if (row.metadata && typeof row.metadata === 'string') {
        metadataFromJson = JSON.parse(row.metadata);
      } else if (typeof row.metadata === 'object' && row.metadata !== null) {
        metadataFromJson = row.metadata;
      }
    } catch (e) {
      console.log('Could not parse metadata JSON:', e.message);
    }

    // Customer name
    let customerName = null;
    try {
      const cResult = await pool.request()
        .input('CustomerId', this.sql.VarChar(50), row.CustomerId)
        .execute('usp_GetCustomerName');

      if (cResult.recordset.length > 0) customerName = cResult.recordset[0].Name;
    } catch (e) {
      console.log('Could not fetch customer name:', e.message);
    }

    const job = new Job({
      jobId,
      customerId:               row.CustomerId,
      customerName,
      blNumber:                 row.BLNumber,
      cusdecNumber:             row.CUSDECNumber,
      cusdecDate:               row.CUSDECDate,
      openDate:                 row.openDate           || row.OpenDate,
      shipmentCategory:         row.shipmentCategory   || row.ShipmentCategory,
      chassisNumber:            row.chassisNumber      || row.ChassisNumber,
      exporter:                 row.Exporter,
      transporter:              row.Transporter,
      lcNumber:                 row.LCNumber,
      containerNumber:          row.ContainerNumber,
      transportDeliveryDate:    row.transportDeliveryDate || row.TransportDeliveryDate,
      status:                   row.Status || 'Open',
      assignedTo:               row.AssignedTo,
      assignedUsers,
      createdDate:              row.createdDate        || row.CreatedDate,
      completedDate:            row.completedDate      || row.CompletedDate,
      pettyCashStatus:          row.pettyCashStatus,
      advancePayment:           row.advancePayment     ?? row.AdvancePayment      ?? 0.00,
      advancePaymentDate:       row.advancePaymentDate || row.AdvancePaymentDate,
      advancePaymentType:       row.advancePaymentType || row.AdvancePaymentType,
      advancePaymentCheckNo:    row.advancePaymentCheckNo || row.AdvancePaymentCheckNo,
      advancePaymentNotes:      row.advancePaymentNotes   || row.AdvancePaymentNotes,
      advancePaymentRecordedBy: row.advancePaymentRecordedBy || row.AdvancePaymentRecordedBy,
      payItems:                 payItems      || [],
      officePayItems:           officePayItems || [],
      metadata:                 metadataFromJson,
      billTotalAmount:          row.billTotalAmount ? parseFloat(row.billTotalAmount) : null,
      billPaidAmount:           row.billPaidAmount  ? parseFloat(row.billPaidAmount)  : 0,
    });

    console.log('mapToEntity result:', job.toJSON());
    return job;
  }
}

module.exports = MSSQLJobRepository;
