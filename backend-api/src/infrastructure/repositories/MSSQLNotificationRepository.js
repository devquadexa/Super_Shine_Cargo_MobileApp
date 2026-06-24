/**
 * MSSQL Notification Repository
 * All database operations are delegated to stored procedures.
 */
const Notification = require('../../domain/entities/Notification');

class MSSQLNotificationRepository {
  constructor(getConnection, sql) {
    this.getConnection = getConnection;
    this.sql = sql;
  }

  async generateNextId() {
    const pool = await this.getConnection();

    const result = await pool.request()
      .execute('usp_GenerateNextNotificationId');

    return result.recordset[0].NextNotificationId;
  }

  async create(notification) {
    const pool = await this.getConnection();

    await pool.request()
      .input('NotificationId', this.sql.VarChar(50),    notification.notificationId)
      .input('UserId',         this.sql.VarChar(50),    notification.userId)
      .input('Type',           this.sql.VarChar(100),   notification.type)
      .input('Title',          this.sql.NVarChar(500),  notification.title)
      .input('Message',        this.sql.NVarChar(4000), notification.message)
      .input('RelatedId',      this.sql.VarChar(50),    notification.relatedId)
      .input('RelatedType',    this.sql.VarChar(100),   notification.relatedType)
      .input('IsRead',         this.sql.Bit,            notification.isRead ? 1 : 0)
      .input('ReadDate',       this.sql.DateTime,       notification.readDate)
      .input('Metadata',       this.sql.NVarChar(4000), JSON.stringify(notification.metadata))
      .input('CreatedDate',    this.sql.DateTime,       notification.createdDate)
      .input('CreatedBy',      this.sql.VarChar(50),    notification.createdBy)
      .execute('usp_CreateNotification');

    return notification;
  }

  async findById(notificationId) {
    const pool = await this.getConnection();

    const result = await pool.request()
      .input('NotificationId', this.sql.VarChar(50), notificationId)
      .execute('usp_GetNotificationById');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async findByUserId(userId, limit = 50, offset = 0) {
    const pool = await this.getConnection();

    const result = await pool.request()
      .input('UserId', this.sql.VarChar(50), userId)
      .input('Limit',  this.sql.Int,         limit)
      .input('Offset', this.sql.Int,         offset)
      .execute('usp_GetNotificationsByUser');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findUnreadByUserId(userId, limit = 50, offset = 0) {
    const pool = await this.getConnection();

    const result = await pool.request()
      .input('UserId', this.sql.VarChar(50), userId)
      .input('Limit',  this.sql.Int,         limit)
      .input('Offset', this.sql.Int,         offset)
      .execute('usp_GetUnreadNotificationsByUser');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async getUnreadCount(userId) {
    const pool = await this.getConnection();

    const result = await pool.request()
      .input('UserId', this.sql.VarChar(50), userId)
      .execute('usp_GetUnreadNotificationCount');

    return result.recordset[0].unreadCount;
  }

  async findByRelatedId(relatedId) {
    const pool = await this.getConnection();

    const result = await pool.request()
      .input('RelatedId', this.sql.VarChar(50), relatedId)
      .execute('usp_GetNotificationsByRelatedId');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async findByType(type, limit = 50, offset = 0) {
    const pool = await this.getConnection();

    const result = await pool.request()
      .input('Type',   this.sql.VarChar(100), type)
      .input('Limit',  this.sql.Int,          limit)
      .input('Offset', this.sql.Int,          offset)
      .execute('usp_GetNotificationsByType');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async markAsRead(notificationId) {
    const pool = await this.getConnection();

    await pool.request()
      .input('NotificationId', this.sql.VarChar(50), notificationId)
      .input('ReadDate',       this.sql.DateTime,    new Date())
      .execute('usp_MarkNotificationAsRead');

    return this.findById(notificationId);
  }

  async markAsUnread(notificationId) {
    const pool = await this.getConnection();

    await pool.request()
      .input('NotificationId', this.sql.VarChar(50), notificationId)
      .execute('usp_MarkNotificationAsUnread');

    return this.findById(notificationId);
  }

  async markAllAsRead(userId) {
    const pool = await this.getConnection();

    await pool.request()
      .input('UserId',   this.sql.VarChar(50), userId)
      .input('ReadDate', this.sql.DateTime,    new Date())
      .execute('usp_MarkAllNotificationsAsRead');

    return { success: true };
  }

  async delete(notificationId) {
    const pool = await this.getConnection();

    await pool.request()
      .input('NotificationId', this.sql.VarChar(50), notificationId)
      .execute('usp_DeleteNotification');

    return { success: true };
  }

  async deleteByUserId(userId) {
    const pool = await this.getConnection();

    await pool.request()
      .input('UserId', this.sql.VarChar(50), userId)
      .execute('usp_DeleteNotificationsByUser');

    return { success: true };
  }

  async deleteOldNotifications(daysOld = 30) {
    const pool = await this.getConnection();

    const result = await pool.request()
      .input('DaysOld', this.sql.Int, daysOld)
      .execute('usp_DeleteOldNotifications');

    return { deletedCount: result.rowsAffected[0] };
  }

  mapToEntity(row) {
    return new Notification({
      notificationId: row.notificationId,
      userId:         row.userId,
      type:           row.type,
      title:          row.title,
      message:        row.message,
      relatedId:      row.relatedId,
      relatedType:    row.relatedType,
      isRead:         row.isRead === 1 || row.isRead === true,
      readDate:       row.readDate,
      metadata:       row.metadata ? JSON.parse(row.metadata) : {},
      createdDate:    row.createdDate,
      createdBy:      row.createdBy,
    });
  }
}

module.exports = MSSQLNotificationRepository;
