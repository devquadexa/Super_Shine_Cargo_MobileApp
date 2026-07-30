const IPettyCashAssignmentRepository = require('../../domain/repositories/IPettyCashAssignmentRepository');
const PettyCashAssignment = require('../../domain/entities/PettyCashAssignment');

class MSSQLPettyCashAssignmentRepository extends IPettyCashAssignmentRepository {
  constructor(getConnection, sql) {
    super();
    this.getConnection = getConnection;
    this.sql = sql;
  }

  async create(assignmentData) {
    try {
      const pool = await this.getConnection();

      let groupId = assignmentData.groupId || `${assignmentData.jobId}_${assignmentData.assignedTo}`;

      if (!assignmentData.groupId) {
        const lastResult = await pool.request()
          .input('JobId',      this.sql.VarChar(50), assignmentData.jobId)
          .input('AssignedTo', this.sql.VarChar(50), assignmentData.assignedTo)
          .execute('usp_GetLastPettyCashAssignment');

        if (lastResult.recordset.length > 0) {
          const last = lastResult.recordset[0];
          const settledStatuses = [
            'Full Petty Cash Returned',
            'Settled / Balance Returned',
            'Settled / Over Due Collected',
            'Settled'
          ];
          if (settledStatuses.includes(last.status)) {
            groupId = `${assignmentData.jobId}_${assignmentData.assignedTo}_${Date.now()}`;
            console.log('create - Settled status detected, creating new independent group:', groupId);
          } else {
            groupId = last.groupId || `${assignmentData.jobId}_${assignmentData.assignedTo}`;
            console.log('create - Using existing groupId for same job+user:', groupId);
          }
        }
      }

      const result = await pool.request()
        .input('JobId',          this.sql.VarChar(50),    assignmentData.jobId)
        .input('AssignedTo',     this.sql.VarChar(50),    assignmentData.assignedTo)
        .input('AssignedBy',     this.sql.VarChar(50),    assignmentData.assignedBy)
        .input('AssignedAmount', this.sql.Decimal(18, 2), assignmentData.assignedAmount)
        .input('Notes',          this.sql.NVarChar(4000), assignmentData.notes || null)
        .input('GroupId',        this.sql.NVarChar(200),  groupId)
        .execute('usp_CreatePettyCashAssignment');

      console.log('create - New assignment created with groupId:', groupId);

      await pool.request()
        .input('JobId', this.sql.VarChar(50), assignmentData.jobId)
        .execute('usp_SetJobPettyCashAssigned');

      return new PettyCashAssignment({ ...result.recordset[0], groupId });
    } catch (error) {
      console.error('Error creating petty cash assignment:', error);
      throw error;
    }
  }

  async getAll() {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .execute('usp_GetAllPettyCashAssignments');

      const assignments = await Promise.all(result.recordset.map(async (assignment) => {
        const items = await this.getSettlementItems(assignment.assignmentId);
        return new PettyCashAssignment({ ...assignment, settlementItems: items });
      }));

      return assignments;
    } catch (error) {
      console.error('Error fetching all assignments:', error);
      throw error;
    }
  }

  async findAll() {
    return this.getAll();
  }

  async getByUser(userId) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('UserId', this.sql.VarChar(50), userId)
        .execute('usp_GetPettyCashAssignmentsByUser');

      const assignments = await Promise.all(result.recordset.map(async (assignment) => {
        const items = await this.getSettlementItems(assignment.assignmentId);
        return new PettyCashAssignment({ ...assignment, settlementItems: items });
      }));

      return assignments;
    } catch (error) {
      console.error('Error fetching assignments by user:', error);
      throw error;
    }
  }

  async getByJob(jobId) {
    try {
      console.log('getByJob - jobId:', jobId);
      const pool = await this.getConnection();

      const queryResult = await pool.request()
        .input('JobId', this.sql.VarChar(50), jobId)
        .execute('usp_GetPettyCashAssignmentsByJob');

      console.log('getByJob - result count:', queryResult.recordset.length);

      if (queryResult.recordset.length === 0) {
        console.log('getByJob - No assignment found');
        return null;
      }

      let allSettlementItems = [];
      for (const assignment of queryResult.recordset) {
        const items = await this.getSettlementItems(assignment.assignmentId);
        allSettlementItems = allSettlementItems.concat(items);
      }

      const assignment = queryResult.recordset[0];
      return new PettyCashAssignment({ ...assignment, settlementItems: allSettlementItems });
    } catch (error) {
      console.error('Error fetching assignment by job:', error);
      throw error;
    }
  }

  async getById(assignmentId) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('AssignmentId', this.sql.Int, assignmentId)
        .execute('usp_GetPettyCashAssignmentById');

      if (result.recordset.length === 0) return null;

      const assignment = result.recordset[0];
      const items = await this.getSettlementItems(assignmentId);

      return new PettyCashAssignment({ ...assignment, settlementItems: items });
    } catch (error) {
      console.error('Error fetching assignment by id:', error);
      throw error;
    }
  }

  async findById(assignmentId) {
    return this.getById(assignmentId);
  }

  async getSettlementItems(assignmentId) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('AssignmentId', this.sql.Int, assignmentId)
        .execute('usp_GetSettlementItems');

      return result.recordset;
    } catch (error) {
      console.error('Error fetching settlement items:', error);
      throw error;
    }
  }

  async settle(assignmentId, settlementData, options = {}) {
    try {
      console.log('=== SETTLE START ===');
      const pool = await this.getConnection();
      const transaction = new this.sql.Transaction(pool);

      await transaction.begin();

      try {
        const assignment = await this.getById(assignmentId);

        // Process each settlement item
        for (const item of settlementData.items) {
          if (!item.isCustomItem) {
            // Check if predefined item already claimed by another assignment for this job
            const existingResult = await transaction.request()
              .input('JobId',        this.sql.VarChar(50),    assignment.jobId)
              .input('AssignmentId', this.sql.Int,             assignmentId)
              .input('ItemName',     this.sql.NVarChar(500),   item.itemName)
              .execute('usp_GetExistingPredefinedSettlementItem');

            if (existingResult.recordset.length > 0) {
              const existing = existingResult.recordset[0];
              console.log(`settle - skipping predefined item '${item.itemName}' - already in assignment ${existing.assignmentId}`);
              continue;
            }

            // Upsert: remove existing entry for same item in this assignment before re-inserting
            await transaction.request()
              .input('AssignmentId', this.sql.Int,           assignmentId)
              .input('ItemName',     this.sql.NVarChar(500),  item.itemName)
              .input('IsCustomItem', this.sql.Bit,            0)
              .execute('usp_DeleteSettlementItemByName');
          } else {
            // Deduplicate custom items for this assignment
            await transaction.request()
              .input('AssignmentId', this.sql.Int,           assignmentId)
              .input('ItemName',     this.sql.NVarChar(500),  item.itemName)
              .input('IsCustomItem', this.sql.Bit,            1)
              .execute('usp_DeleteSettlementItemByName');
          }

          const hasBillValue = (item.hasBill === true || item.hasBill === 1 || item.hasBill === 'true') ? 1 : 0;

          await transaction.request()
            .input('AssignmentId', this.sql.Int,            assignmentId)
            .input('ItemName',     this.sql.NVarChar(500),  item.itemName)
            .input('ActualCost',   this.sql.Decimal(18, 2), item.actualCost)
            .input('IsCustomItem', this.sql.Bit,            item.isCustomItem ? 1 : 0)
            .input('PaidBy',       this.sql.VarChar(50),    item.paidBy || assignment.assignedTo)
            .input('HasBill',      this.sql.Bit,            hasBillValue)
            .execute('usp_InsertSettlementItem');
        }

        // Calculate total spent — aggregate sub-assignments if this is a parent
        let actualSpent = 0;
        let assignedAmount = parseFloat(assignment.assignedAmount);

        if (assignment.isMainAssignment) {
          const subResult = await transaction.request()
            .input('ParentAssignmentId', this.sql.Int, assignmentId)
            .execute('usp_GetSubAssignmentIds');

          const subIds = subResult.recordset.map(r => r.assignmentId);

          if (subIds.length > 0) {
            const totalResult = await transaction.request()
              .input('ParentAssignmentId', this.sql.Int, assignmentId)
              .execute('usp_SumSettlementItemsByParent');

            actualSpent = parseFloat(totalResult.recordset[0].totalSpent) || 0;

            const assignedTotalResult = await transaction.request()
              .input('ParentAssignmentId', this.sql.Int, assignmentId)
              .execute('usp_SumSubAssignmentAmounts');

            const subTotal = parseFloat(assignedTotalResult.recordset[0].totalAssigned) || 0;
            if (subTotal > 0) assignedAmount = subTotal;
          } else {
            const totalResult = await transaction.request()
              .input('AssignmentId', this.sql.Int, assignmentId)
              .execute('usp_SumSettlementItemsByAssignment');

            actualSpent = parseFloat(totalResult.recordset[0].totalSpent) || 0;
          }
        } else {
          const totalResult = await transaction.request()
            .input('AssignmentId', this.sql.Int, assignmentId)
            .execute('usp_SumSettlementItemsByAssignment');

          actualSpent = parseFloat(totalResult.recordset[0].totalSpent) || 0;
        }

        const balanceAmount = assignedAmount > actualSpent ? assignedAmount - actualSpent : 0;
        const overAmount    = actualSpent > assignedAmount ? actualSpent - assignedAmount : 0;

        // Determine status
        let newStatus = 'Settled';
        if (actualSpent === 0 && balanceAmount === assignedAmount) {
          newStatus = 'Full Petty Cash Returned';
        } else if (balanceAmount > 0) {
          newStatus = 'Balance To Be Return';
        } else if (overAmount > 0) {
          newStatus = 'Over Due';
        }

        // Allow group settle to override status based on group totals
        if (options.overrideStatus) {
          newStatus = options.overrideStatus;
        }

        console.log('settle - status:', newStatus, '| actualSpent:', actualSpent, '| balance:', balanceAmount, '| over:', overAmount);

        await transaction.request()
          .input('AssignmentId',  this.sql.Int,            assignmentId)
          .input('Status',        this.sql.NVarChar(100),  newStatus)
          .input('ActualSpent',   this.sql.Decimal(18, 2), actualSpent)
          .input('BalanceAmount', this.sql.Decimal(18, 2), balanceAmount)
          .input('OverAmount',    this.sql.Decimal(18, 2), overAmount)
          .execute('usp_SettlePettyCashAssignment');

        // Update job pettyCashStatus if all assignments for the job are in final state
        const unsettledResult = await transaction.request()
          .input('JobId', this.sql.VarChar(50), assignment.jobId)
          .execute('usp_CountUnsettledPettyCashAssignments');

        if (unsettledResult.recordset[0].unsettledCount === 0) {
          await transaction.request()
            .input('JobId', this.sql.VarChar(50), assignment.jobId)
            .execute('usp_SetJobPettyCashSettled');
        }

        await transaction.commit();
        console.log('=== SETTLE END ===');

        return await this.getById(assignmentId);
      } catch (error) {
        await transaction.rollback();
        throw error;
      }
    } catch (error) {
      console.error('Error in settle:', error);
      throw error;
    }
  }

  async updateStatus(assignmentId, status) {
    try {
      const pool = await this.getConnection();

      await pool.request()
        .input('AssignmentId', this.sql.Int,           assignmentId)
        .input('Status',       this.sql.NVarChar(100), status)
        .execute('usp_UpdatePettyCashAssignmentStatus');

      return await this.getById(assignmentId);
    } catch (error) {
      console.error('Error updating assignment status:', error);
      throw error;
    }
  }

  async recalculateStatus(assignmentId) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('AssignmentId', this.sql.Int, assignmentId)
        .execute('usp_GetPettyCashAssignmentAmounts');

      if (!result.recordset.length) throw new Error('Assignment not found');

      const row = result.recordset[0];
      const settledStatuses = ['Settled', 'Balance To Be Return', 'Over Due'];
      if (!settledStatuses.includes(row.status)) return await this.getById(assignmentId);

      const assignedAmount = parseFloat(row.assignedAmount) || 0;
      const actualSpent    = parseFloat(row.actualSpent)    || 0;
      const recalcBalance  = assignedAmount > actualSpent ? assignedAmount - actualSpent : 0;
      const recalcOver     = actualSpent > assignedAmount ? actualSpent - assignedAmount : 0;

      let correctStatus = 'Settled';
      if (recalcBalance > 0)   correctStatus = 'Balance To Be Return';
      else if (recalcOver > 0) correctStatus = 'Over Due';

      await pool.request()
        .input('AssignmentId',  this.sql.Int,            assignmentId)
        .input('Status',        this.sql.NVarChar(100),  correctStatus)
        .input('BalanceAmount', this.sql.Decimal(18, 2), recalcBalance)
        .input('OverAmount',    this.sql.Decimal(18, 2), recalcOver)
        .execute('usp_RecalculatePettyCashAssignmentStatus');

      return await this.getById(assignmentId);
    } catch (error) {
      console.error('Error recalculating assignment status:', error);
      throw error;
    }
  }

  async closeAllByJob(jobId) {
    try {
      const pool = await this.getConnection();

      await pool.request()
        .input('JobId', this.sql.VarChar(50), jobId)
        .execute('usp_CloseAllPettyCashAssignmentsByJob');
    } catch (error) {
      console.error('Error closing petty cash assignments for job:', error);
      throw error;
    }
  }

  async updateStatusAndClearAmount(assignmentId, newStatus, settlementType) {
    try {
      const pool = await this.getConnection();

      await pool.request()
        .input('AssignmentId',   this.sql.Int,           assignmentId)
        .input('Status',         this.sql.NVarChar(100), newStatus)
        .input('SettlementType', this.sql.VarChar(30),   settlementType || null)
        .execute('usp_UpdatePettyCashStatusAndClearAmount');

      return await this.getById(assignmentId);
    } catch (error) {
      console.error('Error updating assignment status:', error);
      throw error;
    }
  }

  async returnBalance(assignmentId) {
    try {
      const pool = await this.getConnection();

      await pool.request()
        .input('AssignmentId', this.sql.Int,           assignmentId)
        .input('Status',       this.sql.NVarChar(100), 'Returned')
        .execute('usp_UpdatePettyCashAssignmentStatus');

      return await this.getById(assignmentId);
    } catch (error) {
      console.error('Error returning balance:', error);
      throw error;
    }
  }

  async payOverAmount(assignmentId) {
    try {
      const pool = await this.getConnection();

      await pool.request()
        .input('AssignmentId', this.sql.Int,           assignmentId)
        .input('Status',       this.sql.NVarChar(100), 'Paid')
        .execute('usp_UpdatePettyCashAssignmentStatus');

      return await this.getById(assignmentId);
    } catch (error) {
      console.error('Error paying over amount:', error);
      throw error;
    }
  }

  async getByJobAndUser(jobId, userId, assignmentId = null) {
    try {
      console.log('getByJobAndUser - jobId:', jobId, 'userId:', userId, 'assignmentId:', assignmentId);
      const pool = await this.getConnection();

      const queryResult = await pool.request()
        .input('JobId',        this.sql.VarChar(50), jobId)
        .input('UserId',       this.sql.VarChar(50), userId)
        .input('AssignmentId', this.sql.Int,         assignmentId || null)
        .execute('usp_GetPettyCashAssignmentByJobAndUser');

      if (queryResult.recordset.length === 0) return null;

      const assignment = queryResult.recordset[0];
      const userOwnItems = await this.getSettlementItems(assignment.assignmentId);

      const otherItemsResult = await pool.request()
        .input('JobId',        this.sql.VarChar(50), jobId)
        .input('AssignmentId', this.sql.Int,         assignment.assignmentId)
        .execute('usp_GetOtherAssignmentsPredefinedItems');

      const userOwnItemIds    = new Set(userOwnItems.map(i => i.settlementItemId));
      const userEditableItems = userOwnItems.map(i => ({ ...i, isReadOnly: false, isOwnItem: true, countInTotalSpent: true }));

      const otherItems = otherItemsResult.recordset
        .filter(i => !userOwnItemIds.has(i.settlementItemId) && (i.isCustomItem === 0 || i.isCustomItem === false))
        .map(i => ({ ...i, isReadOnly: true, isOwnItem: false, countInTotalSpent: false }));

      const userOwnTotalSpent = userEditableItems.reduce((sum, i) => sum + parseFloat(i.actualCost || 0), 0);

      return new PettyCashAssignment({
        ...assignment,
        actualSpent:               userOwnTotalSpent,
        balanceAmount:             parseFloat(assignment.assignedAmount) - userOwnTotalSpent,
        overAmount:                userOwnTotalSpent > parseFloat(assignment.assignedAmount) ? userOwnTotalSpent - parseFloat(assignment.assignedAmount) : 0,
        settlementItems:           userEditableItems,
        readOnlyPredefinedItems:   otherItems,
      });
    } catch (error) {
      console.error('Error fetching assignment by job and user:', error);
      throw error;
    }
  }

  async getAllByJob(jobId) {
    try {
      console.log('getAllByJob - jobId:', jobId);
      const pool = await this.getConnection();

      const queryResult = await pool.request()
        .input('JobId', this.sql.VarChar(50), jobId)
        .execute('usp_GetPettyCashAssignmentsByJob');

      const assignments = await Promise.all(queryResult.recordset.map(async (assignment) => {
        const settlementItems = await this.getSettlementItems(assignment.assignmentId);
        return new PettyCashAssignment({ ...assignment, settlementItems });
      }));

      return assignments;
    } catch (error) {
      console.error('Error fetching all assignments by job:', error);
      throw error;
    }
  }

  async updateSettlementItem(itemId, itemName, actualCost) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('ItemId',     this.sql.Int,            itemId)
        .input('ItemName',   this.sql.NVarChar(500),  itemName)
        .input('ActualCost', this.sql.Decimal(18, 2), actualCost)
        .execute('usp_UpdateSettlementItem');

      if (result.recordset.length === 0) throw new Error('Settlement item not found');
      return result.recordset[0];
    } catch (error) {
      console.error('Error updating settlement item:', error);
      throw error;
    }
  }

  async deleteSettlementItem(itemId) {
    try {
      const pool = await this.getConnection();

      await pool.request()
        .input('ItemId', this.sql.Int, itemId)
        .execute('usp_DeleteSettlementItemById');

      return true;
    } catch (error) {
      console.error('Error deleting settlement item:', error);
      throw error;
    }
  }

  async recalculateAssignmentTotals(assignmentId) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('AssignmentId', this.sql.Int, assignmentId)
        .execute('usp_RecalculatePettyCashAssignmentTotals');

      return result.recordset[0];
    } catch (error) {
      console.error('Error recalculating assignment totals:', error);
      throw error;
    }
  }

  async createSubAssignment(assignmentData) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('JobId',              this.sql.VarChar(50),    assignmentData.jobId)
        .input('AssignedTo',         this.sql.VarChar(50),    assignmentData.assignedTo)
        .input('AssignedBy',         this.sql.VarChar(50),    assignmentData.assignedBy)
        .input('AssignedAmount',     this.sql.Decimal(18, 2), assignmentData.assignedAmount)
        .input('Notes',              this.sql.NVarChar(4000), assignmentData.notes || null)
        .input('GroupId',            this.sql.NVarChar(200),  assignmentData.groupId)
        .input('ParentAssignmentId', this.sql.Int,            assignmentData.parentAssignmentId)
        .execute('usp_CreateSubPettyCashAssignment');

      return result.recordset[0];
    } catch (error) {
      console.error('Error creating sub-assignment:', error);
      throw error;
    }
  }

  async getMainAssignments(userId = null) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('UserId', this.sql.VarChar(50), userId || null)
        .execute('usp_GetMainPettyCashAssignments');

      return result.recordset;
    } catch (error) {
      console.error('Error fetching main assignments:', error);
      throw error;
    }
  }

  async getSubAssignments(parentAssignmentId) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('ParentAssignmentId', this.sql.Int, parentAssignmentId)
        .execute('usp_GetSubPettyCashAssignments');

      return result.recordset;
    } catch (error) {
      console.error('Error fetching sub-assignments:', error);
      throw error;
    }
  }

  async getTotalAssignedAmount(mainAssignmentId) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('MainAssignmentId', this.sql.Int, mainAssignmentId)
        .execute('usp_GetTotalPettyCashAssignedAmount');

      return parseFloat(result.recordset[0].totalAmount || 0);
    } catch (error) {
      console.error('Error calculating total assigned amount:', error);
      throw error;
    }
  }

  async findByDateRange(fromDate, toDate) {
    try {
      const pool = await this.getConnection();

      const fromDateStr = fromDate instanceof Date ? fromDate.toISOString().split('T')[0] : fromDate;
      const toDateStr   = toDate   instanceof Date ? toDate.toISOString().split('T')[0]   : toDate;

      const result = await pool.request()
        .input('FromDate', this.sql.VarChar(10), fromDateStr)
        .input('ToDate',   this.sql.VarChar(10), toDateStr)
        .execute('usp_GetPettyCashAssignmentsByDateRange');

      return result.recordset;
    } catch (error) {
      console.error('Error fetching assignments by date range:', error);
      throw error;
    }
  }

  async findByDate(date) {
    return this.findByDateRange(date, date);
  }
}

module.exports = MSSQLPettyCashAssignmentRepository;
