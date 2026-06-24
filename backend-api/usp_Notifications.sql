-- =============================================================================
-- Stored Procedures: Notifications
-- Repository: MSSQLNotificationRepository
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. usp_GenerateNextNotificationId
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GenerateNextNotificationId', 'P') IS NOT NULL DROP PROCEDURE usp_GenerateNextNotificationId;
GO
CREATE PROCEDURE usp_GenerateNextNotificationId
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NextId INT;
    SELECT @NextId = ISNULL(MAX(CAST(SUBSTRING(notificationId, 6, LEN(notificationId)) AS INT)), 0) + 1
    FROM Notifications WHERE notificationId LIKE 'NOTIF%';
    SELECT 'NOTIF' + RIGHT('00000' + CAST(@NextId AS VARCHAR(5)), 5) AS NextNotificationId;
END;
GO

-- -----------------------------------------------------------------------------
-- 2. usp_CreateNotification
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreateNotification', 'P') IS NOT NULL DROP PROCEDURE usp_CreateNotification;
GO
CREATE PROCEDURE usp_CreateNotification
    @NotificationId VARCHAR(50),
    @UserId         VARCHAR(50),
    @Type           VARCHAR(100),
    @Title          NVARCHAR(500),
    @Message        NVARCHAR(MAX),
    @RelatedId      VARCHAR(50),
    @RelatedType    VARCHAR(100),
    @IsRead         BIT,
    @ReadDate       DATETIME,
    @Metadata       NVARCHAR(MAX),
    @CreatedDate    DATETIME,
    @CreatedBy      VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Notifications (
        notificationId, userId, type, title, message, relatedId, relatedType,
        isRead, readDate, metadata, createdDate, createdBy
    )
    VALUES (
        @NotificationId, @UserId, @Type, @Title, @Message, @RelatedId, @RelatedType,
        @IsRead, @ReadDate, @Metadata, @CreatedDate, @CreatedBy
    );
END;
GO

-- -----------------------------------------------------------------------------
-- 3. usp_GetNotificationById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetNotificationById', 'P') IS NOT NULL DROP PROCEDURE usp_GetNotificationById;
GO
CREATE PROCEDURE usp_GetNotificationById
    @NotificationId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Notifications WHERE notificationId = @NotificationId;
END;
GO

-- -----------------------------------------------------------------------------
-- 4. usp_GetNotificationsByUser
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetNotificationsByUser', 'P') IS NOT NULL DROP PROCEDURE usp_GetNotificationsByUser;
GO
CREATE PROCEDURE usp_GetNotificationsByUser
    @UserId VARCHAR(50),
    @Limit  INT = 50,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Notifications
    WHERE userId = @UserId
    ORDER BY createdDate DESC
    OFFSET @Offset ROWS FETCH NEXT @Limit ROWS ONLY;
END;
GO

-- -----------------------------------------------------------------------------
-- 5. usp_GetUnreadNotificationsByUser
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetUnreadNotificationsByUser', 'P') IS NOT NULL DROP PROCEDURE usp_GetUnreadNotificationsByUser;
GO
CREATE PROCEDURE usp_GetUnreadNotificationsByUser
    @UserId VARCHAR(50),
    @Limit  INT = 50,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Notifications
    WHERE userId = @UserId AND isRead = 0
    ORDER BY createdDate DESC
    OFFSET @Offset ROWS FETCH NEXT @Limit ROWS ONLY;
END;
GO

-- -----------------------------------------------------------------------------
-- 6. usp_GetUnreadNotificationCount
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetUnreadNotificationCount', 'P') IS NOT NULL DROP PROCEDURE usp_GetUnreadNotificationCount;
GO
CREATE PROCEDURE usp_GetUnreadNotificationCount
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS unreadCount FROM Notifications
    WHERE userId = @UserId AND isRead = 0;
END;
GO

-- -----------------------------------------------------------------------------
-- 7. usp_GetNotificationsByRelatedId
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetNotificationsByRelatedId', 'P') IS NOT NULL DROP PROCEDURE usp_GetNotificationsByRelatedId;
GO
CREATE PROCEDURE usp_GetNotificationsByRelatedId
    @RelatedId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Notifications
    WHERE relatedId = @RelatedId ORDER BY createdDate DESC;
END;
GO

-- -----------------------------------------------------------------------------
-- 8. usp_GetNotificationsByType
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetNotificationsByType', 'P') IS NOT NULL DROP PROCEDURE usp_GetNotificationsByType;
GO
CREATE PROCEDURE usp_GetNotificationsByType
    @Type   VARCHAR(100),
    @Limit  INT = 50,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Notifications
    WHERE type = @Type
    ORDER BY createdDate DESC
    OFFSET @Offset ROWS FETCH NEXT @Limit ROWS ONLY;
END;
GO

-- -----------------------------------------------------------------------------
-- 9. usp_MarkNotificationAsRead
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_MarkNotificationAsRead', 'P') IS NOT NULL DROP PROCEDURE usp_MarkNotificationAsRead;
GO
CREATE PROCEDURE usp_MarkNotificationAsRead
    @NotificationId VARCHAR(50),
    @ReadDate       DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Notifications
    SET isRead = 1, readDate = @ReadDate
    WHERE notificationId = @NotificationId;
END;
GO

-- -----------------------------------------------------------------------------
-- 10. usp_MarkNotificationAsUnread
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_MarkNotificationAsUnread', 'P') IS NOT NULL DROP PROCEDURE usp_MarkNotificationAsUnread;
GO
CREATE PROCEDURE usp_MarkNotificationAsUnread
    @NotificationId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Notifications
    SET isRead = 0, readDate = NULL
    WHERE notificationId = @NotificationId;
END;
GO

-- -----------------------------------------------------------------------------
-- 11. usp_MarkAllNotificationsAsRead
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_MarkAllNotificationsAsRead', 'P') IS NOT NULL DROP PROCEDURE usp_MarkAllNotificationsAsRead;
GO
CREATE PROCEDURE usp_MarkAllNotificationsAsRead
    @UserId   VARCHAR(50),
    @ReadDate DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Notifications
    SET isRead = 1, readDate = @ReadDate
    WHERE userId = @UserId AND isRead = 0;
END;
GO

-- -----------------------------------------------------------------------------
-- 12. usp_DeleteNotification
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeleteNotification', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteNotification;
GO
CREATE PROCEDURE usp_DeleteNotification
    @NotificationId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Notifications WHERE notificationId = @NotificationId;
END;
GO

-- -----------------------------------------------------------------------------
-- 13. usp_DeleteNotificationsByUser
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeleteNotificationsByUser', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteNotificationsByUser;
GO
CREATE PROCEDURE usp_DeleteNotificationsByUser
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Notifications WHERE userId = @UserId;
END;
GO

-- -----------------------------------------------------------------------------
-- 14. usp_DeleteOldNotifications
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeleteOldNotifications', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteOldNotifications;
GO
CREATE PROCEDURE usp_DeleteOldNotifications
    @DaysOld INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Notifications
    WHERE createdDate < DATEADD(day, -@DaysOld, GETDATE());
END;
GO
