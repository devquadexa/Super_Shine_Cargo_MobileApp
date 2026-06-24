/**
 * MSSQL Job Assignment Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const IJobAssignmentRepository = require('../../domain/repositories/IJobAssignmentRepository');
const JobAssignment = require('../../domain/entities/JobAssignment');

class MSSQLJobAssignmentRepository extends IJobAssignmentRepository {
  constructor(dbConnection, sql) {
    super();
    this.db = dbConnection;
    this.sql = sql;
  }

  async create(assignment) {
    const pool = await this.db();

    const result = await pool.request()
      .input('JobId',      this.sql.VarChar(50),    assignment.jobId)
      .input('UserId',     this.sql.VarChar(50),    assignment.userId)
      .input('AssignedBy', this.sql.VarChar(50),    assignment.assignedBy)
      .input('Notes',      this.sql.NVarChar(4000), assignment.notes)
      .execute('usp_CreateJobAssignment');

    assignment.assignmentId = result.recordset[0].assignmentId;
    return assignment;
  }

  async findById(assignmentId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('AssignmentId', this.sql.Int, assignmentId)
      .execute('usp_GetJobAssignmentById');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async findByJobId(jobId, activeOnly = true) {
    const pool = await this.db();

    const result = await pool.request()
      .input('JobId',      this.sql.VarChar(50), jobId)
      .input('ActiveOnly', this.sql.Bit,         activeOnly ? 1 : 0)
      .execute('usp_GetJobAssignmentsByJob');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByUserId(userId, activeOnly = true) {
    const pool = await this.db();

    const result = await pool.request()
      .input('UserId',     this.sql.VarChar(50), userId)
      .input('ActiveOnly', this.sql.Bit,         activeOnly ? 1 : 0)
      .execute('usp_GetJobAssignmentsByUser');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async assignUsersToJob(jobId, userIds, assignedBy, notes = null) {
    const pool = await this.db();
    const transaction = new this.sql.Transaction(pool);

    try {
      await transaction.begin();

      // Deactivate all existing assignments for this job
      await transaction.request()
        .input('JobId', this.sql.VarChar(50), jobId)
        .execute('usp_DeactivateJobAssignments');

      for (const userId of userIds) {
        const existingResult = await transaction.request()
          .input('JobId',  this.sql.VarChar(50), jobId)
          .input('UserId', this.sql.VarChar(50), userId)
          .execute('usp_GetLatestJobAssignment');

        if (existingResult.recordset.length > 0) {
          await transaction.request()
            .input('AssignmentId', this.sql.Int,          existingResult.recordset[0].assignmentId)
            .input('AssignedBy',   this.sql.VarChar(50),    assignedBy)
            .input('Notes',        this.sql.NVarChar(4000), notes)
            .execute('usp_ReactivateJobAssignment');
        } else {
          await transaction.request()
            .input('JobId',      this.sql.VarChar(50),    jobId)
            .input('UserId',     this.sql.VarChar(50),    userId)
            .input('AssignedBy', this.sql.VarChar(50),    assignedBy)
            .input('Notes',      this.sql.NVarChar(4000), notes)
            .execute('usp_InsertJobAssignment');
        }
      }

      await transaction.request()
        .input('JobId',      this.sql.VarChar(50), jobId)
        .input('AssignedTo', this.sql.VarChar(50), userIds[0] || null)
        .execute('usp_UpdateJobAssignedTo');

      await transaction.commit();
      return userIds.length;
    } catch (error) {
      if (transaction._aborted !== true) {
        try { await transaction.rollback(); } catch (e) {
          console.error('Rollback failed in assignUsersToJob:', e);
        }
      }
      console.error('Error in assignUsersToJob:', error);
      throw error;
    }
  }

  async removeUserFromJob(jobId, userId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('JobId',  this.sql.VarChar(50), jobId)
      .input('UserId', this.sql.VarChar(50), userId)
      .execute('usp_RemoveUserFromJob');

    return result.recordset[0].RemovedCount > 0;
  }

  async removeAllAssignmentsForJob(jobId) {
    const pool = await this.db();

    await pool.request()
      .input('JobId', this.sql.VarChar(50), jobId)
      .execute('usp_DeleteAllJobAssignments');

    return true;
  }

  async getJobAssignmentSummary(jobId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('JobId', this.sql.VarChar(50), jobId)
      .execute('usp_GetJobAssignmentSummary');

    if (result.recordset.length === 0) {
      return { jobId, assignedUserCount: 0, assignedUserNames: '', assignedUserIds: '', lastAssignedDate: null };
    }

    return result.recordset[0];
  }

  async isUserAssignedToJob(jobId, userId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('JobId',  this.sql.VarChar(50), jobId)
      .input('UserId', this.sql.VarChar(50), userId)
      .execute('usp_IsUserAssignedToJob');

    return result.recordset[0].count > 0;
  }

  async getJobsForUser(userId, filters = {}) {
    const pool = await this.db();

    const result = await pool.request()
      .input('UserId',     this.sql.VarChar(50), userId)
      .input('Status',     this.sql.VarChar(50), filters.status     || null)
      .input('CustomerId', this.sql.VarChar(50), filters.customerId || null)
      .execute('usp_GetJobsForUser');

    return result.recordset;
  }

  async updateNotes(assignmentId, notes) {
    const pool = await this.db();

    await pool.request()
      .input('AssignmentId', this.sql.Int,          assignmentId)
      .input('Notes',        this.sql.NVarChar(4000), notes)
      .execute('usp_UpdateJobAssignmentNotes');

    return true;
  }

  mapToEntity(row) {
    return new JobAssignment({
      assignmentId:   row.assignmentId,
      jobId:          row.jobId,
      userId:         row.userId,
      assignedDate:   row.assignedDate,
      assignedBy:     row.assignedBy,
      isActive:       row.isActive,
      notes:          row.notes,
      userName:       row.userName,
      userEmail:      row.userEmail,
      userRole:       row.userRole,
      assignedByName: row.assignedByName,
    });
  }
}

module.exports = MSSQLJobAssignmentRepository;
