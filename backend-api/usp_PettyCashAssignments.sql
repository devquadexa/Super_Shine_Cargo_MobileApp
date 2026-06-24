-- =============================================================================
-- Stored Procedures: PettyCashAssignments + PettyCashSettlementItems
-- Repository: MSSQLPettyCashAssignmentRepository
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. usp_GetLastPettyCashAssignment
--    Returns most recent assignment for a job+user (for groupId logic)
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetLastPettyCashAssignment', 'P') IS NOT NULL DROP PROCEDURE usp_GetLastPettyCashAssignment;
GO
CREATE PROCEDURE usp_GetLastPettyCashAssignment
    @JobId      VARCHAR(50),
    @AssignedTo VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 status, ISNULL(groupId, jobId + '_' + assignedTo) AS groupId
    FROM PettyCashAssignments
    WHERE jobId = @JobId AND assignedTo = @AssignedTo
    ORDER BY assignedDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 2. usp_CreatePettyCashAssignment
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreatePettyCashAssignment', 'P') IS NOT NULL DROP PROCEDURE usp_CreatePettyCashAssignment;
GO
CREATE PROCEDURE usp_CreatePettyCashAssignment
    @JobId          VARCHAR(50),
    @AssignedTo     VARCHAR(50),
    @AssignedBy     VARCHAR(50),
    @AssignedAmount DECIMAL(18,2),
    @Notes          NVARCHAR(MAX),
    @GroupId        NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO PettyCashAssignments (jobId, assignedTo, assignedBy, assignedAmount, notes, groupId)
    OUTPUT INSERTED.*
    VALUES (@JobId, @AssignedTo, @AssignedBy, @AssignedAmount, @Notes, @GroupId);
END;
GO


-- -----------------------------------------------------------------------------
-- 3. usp_SetJobPettyCashAssigned
--    Sets pettyCashStatus = 'Assigned' only if currently NULL
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_SetJobPettyCashAssigned', 'P') IS NOT NULL DROP PROCEDURE usp_SetJobPettyCashAssigned;
GO
CREATE PROCEDURE usp_SetJobPettyCashAssigned
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Jobs SET pettyCashStatus = 'Assigned'
    WHERE jobId = @JobId AND pettyCashStatus IS NULL;
END;
GO


-- -----------------------------------------------------------------------------
-- 4. usp_GetAllPettyCashAssignments
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetAllPettyCashAssignments', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllPettyCashAssignments;
GO
CREATE PROCEDURE usp_GetAllPettyCashAssignments
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pca.assignmentId, pca.jobId, pca.assignedTo, pca.assignedBy,
        pca.assignedAmount, pca.assignedDate, pca.status, pca.settlementDate,
        pca.actualSpent, pca.balanceAmount, pca.overAmount, pca.notes,
        pca.parentAssignmentId, pca.isMainAssignment,
        ISNULL(pca.groupId, pca.jobId + '_' + pca.assignedTo) AS groupId,
        j.shipmentCategory, j.customerId,
        u1.fullName AS assignedToName,
        u2.fullName AS assignedByName
    FROM PettyCashAssignments pca
    LEFT JOIN Jobs  j  ON pca.jobId      = j.jobId
    LEFT JOIN Users u1 ON pca.assignedTo = u1.userId
    LEFT JOIN Users u2 ON pca.assignedBy = u2.userId
    ORDER BY pca.assignedDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 5. usp_GetPettyCashAssignmentsByUser
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPettyCashAssignmentsByUser', 'P') IS NOT NULL DROP PROCEDURE usp_GetPettyCashAssignmentsByUser;
GO
CREATE PROCEDURE usp_GetPettyCashAssignmentsByUser
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pca.assignmentId, pca.jobId, pca.assignedTo, pca.assignedBy,
        pca.assignedAmount, pca.assignedDate, pca.status, pca.settlementDate,
        pca.actualSpent, pca.balanceAmount, pca.overAmount, pca.notes,
        pca.parentAssignmentId, pca.isMainAssignment,
        ISNULL(pca.groupId, pca.jobId + '_' + pca.assignedTo) AS groupId,
        j.shipmentCategory, j.customerId,
        u2.fullName AS assignedByName
    FROM PettyCashAssignments pca
    LEFT JOIN Jobs  j  ON pca.jobId      = j.jobId
    LEFT JOIN Users u2 ON pca.assignedBy = u2.userId
    WHERE pca.assignedTo = @UserId
    ORDER BY pca.assignedDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 6. usp_GetPettyCashAssignmentsByJob
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPettyCashAssignmentsByJob', 'P') IS NOT NULL DROP PROCEDURE usp_GetPettyCashAssignmentsByJob;
GO
CREATE PROCEDURE usp_GetPettyCashAssignmentsByJob
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pca.*,
        j.shipmentCategory,
        u1.fullName AS assignedToName,
        u2.fullName AS assignedByName
    FROM PettyCashAssignments pca
    LEFT JOIN Jobs  j  ON pca.jobId      = j.jobId
    LEFT JOIN Users u1 ON pca.assignedTo = u1.userId
    LEFT JOIN Users u2 ON pca.assignedBy = u2.userId
    WHERE pca.jobId = @JobId
    ORDER BY pca.assignedDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 7. usp_GetPettyCashAssignmentById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPettyCashAssignmentById', 'P') IS NOT NULL DROP PROCEDURE usp_GetPettyCashAssignmentById;
GO
CREATE PROCEDURE usp_GetPettyCashAssignmentById
    @AssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pca.*,
        j.shipmentCategory, j.customerId,
        u1.fullName AS assignedToName,
        u2.fullName AS assignedByName
    FROM PettyCashAssignments pca
    LEFT JOIN Jobs  j  ON pca.jobId      = j.jobId
    LEFT JOIN Users u1 ON pca.assignedTo = u1.userId
    LEFT JOIN Users u2 ON pca.assignedBy = u2.userId
    WHERE pca.assignmentId = @AssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 8. usp_GetSettlementItems
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetSettlementItems', 'P') IS NOT NULL DROP PROCEDURE usp_GetSettlementItems;
GO
CREATE PROCEDURE usp_GetSettlementItems
    @AssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        si.settlementItemId, si.assignmentId, si.itemName, si.actualCost,
        si.isCustomItem, si.hasBill, si.paidBy,
        u.fullName AS paidByName,
        u.email    AS paidByEmail
    FROM PettyCashSettlementItems si
    LEFT JOIN Users u ON si.paidBy = u.userId
    WHERE si.assignmentId = @AssignmentId
    ORDER BY si.settlementItemId;
END;
GO


-- -----------------------------------------------------------------------------
-- 9. usp_GetExistingPredefinedSettlementItem
--    Used in settle() to check if a predefined item is already claimed by
--    another assignment for the same job
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetExistingPredefinedSettlementItem', 'P') IS NOT NULL DROP PROCEDURE usp_GetExistingPredefinedSettlementItem;
GO
CREATE PROCEDURE usp_GetExistingPredefinedSettlementItem
    @JobId        VARCHAR(50),
    @AssignmentId INT,
    @ItemName     NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT si.settlementItemId, si.assignmentId, si.paidBy, u.fullName AS paidByName
    FROM PettyCashSettlementItems si
    INNER JOIN PettyCashAssignments pca ON si.assignmentId = pca.assignmentId
    LEFT  JOIN Users u ON si.paidBy = u.userId
    WHERE pca.jobId         = @JobId
      AND si.itemName       = @ItemName
      AND si.isCustomItem   = 0
      AND si.assignmentId  <> @AssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 10. usp_DeleteSettlementItemByName
--     Removes an item by name+type within an assignment (upsert pre-step)
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeleteSettlementItemByName', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteSettlementItemByName;
GO
CREATE PROCEDURE usp_DeleteSettlementItemByName
    @AssignmentId INT,
    @ItemName     NVARCHAR(500),
    @IsCustomItem BIT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM PettyCashSettlementItems
    WHERE assignmentId = @AssignmentId
      AND itemName     = @ItemName
      AND isCustomItem = @IsCustomItem;
END;
GO


-- -----------------------------------------------------------------------------
-- 11. usp_InsertSettlementItem
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_InsertSettlementItem', 'P') IS NOT NULL DROP PROCEDURE usp_InsertSettlementItem;
GO
CREATE PROCEDURE usp_InsertSettlementItem
    @AssignmentId INT,
    @ItemName     NVARCHAR(500),
    @ActualCost   DECIMAL(18,2),
    @IsCustomItem BIT,
    @PaidBy       VARCHAR(50),
    @HasBill      BIT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO PettyCashSettlementItems
        (assignmentId, itemName, actualCost, isCustomItem, paidBy, hasBill)
    OUTPUT INSERTED.settlementItemId, INSERTED.hasBill
    VALUES
        (@AssignmentId, @ItemName, @ActualCost, @IsCustomItem, @PaidBy, @HasBill);
END;
GO


-- -----------------------------------------------------------------------------
-- 12. usp_GetSubAssignmentIds
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetSubAssignmentIds', 'P') IS NOT NULL DROP PROCEDURE usp_GetSubAssignmentIds;
GO
CREATE PROCEDURE usp_GetSubAssignmentIds
    @ParentAssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT assignmentId FROM PettyCashAssignments
    WHERE parentAssignmentId = @ParentAssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 13. usp_SumSettlementItemsByAssignment
--     Sums actualCost for a single assignment's own items
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_SumSettlementItemsByAssignment', 'P') IS NOT NULL DROP PROCEDURE usp_SumSettlementItemsByAssignment;
GO
CREATE PROCEDURE usp_SumSettlementItemsByAssignment
    @AssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(SUM(actualCost), 0) AS totalSpent
    FROM PettyCashSettlementItems
    WHERE assignmentId = @AssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 14. usp_SumSettlementItemsByParent
--     Sums actualCost across all sub-assignments of a parent
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_SumSettlementItemsByParent', 'P') IS NOT NULL DROP PROCEDURE usp_SumSettlementItemsByParent;
GO
CREATE PROCEDURE usp_SumSettlementItemsByParent
    @ParentAssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(SUM(si.actualCost), 0) AS totalSpent
    FROM PettyCashSettlementItems si
    INNER JOIN PettyCashAssignments pca ON si.assignmentId = pca.assignmentId
    WHERE pca.parentAssignmentId = @ParentAssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 15. usp_SumSubAssignmentAmounts
--     Sums assignedAmount across all sub-assignments of a parent
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_SumSubAssignmentAmounts', 'P') IS NOT NULL DROP PROCEDURE usp_SumSubAssignmentAmounts;
GO
CREATE PROCEDURE usp_SumSubAssignmentAmounts
    @ParentAssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(SUM(assignedAmount), 0) AS totalAssigned
    FROM PettyCashAssignments
    WHERE parentAssignmentId = @ParentAssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 16. usp_SettlePettyCashAssignment
--     Updates amounts and status after settle() calculation
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_SettlePettyCashAssignment', 'P') IS NOT NULL DROP PROCEDURE usp_SettlePettyCashAssignment;
GO
CREATE PROCEDURE usp_SettlePettyCashAssignment
    @AssignmentId  INT,
    @Status        NVARCHAR(100),
    @ActualSpent   DECIMAL(18,2),
    @BalanceAmount DECIMAL(18,2),
    @OverAmount    DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PettyCashAssignments
    SET status         = @Status,
        settlementDate = GETDATE(),
        actualSpent    = @ActualSpent,
        balanceAmount  = @BalanceAmount,
        overAmount     = @OverAmount
    WHERE assignmentId = @AssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 17. usp_CountUnsettledPettyCashAssignments
--     Returns count of assignments not yet in a final state for a job
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CountUnsettledPettyCashAssignments', 'P') IS NOT NULL DROP PROCEDURE usp_CountUnsettledPettyCashAssignments;
GO
CREATE PROCEDURE usp_CountUnsettledPettyCashAssignments
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS unsettledCount
    FROM PettyCashAssignments
    WHERE jobId = @JobId
      AND status NOT IN (
        'Settled','Balance To Be Return','Over Due',
        'Pending Approval / Balance','Pending Approval / Over Due',
        'Settled / Balance Returned','Settled / Over Due Collected',
        'Full Petty Cash Returned','Closed',
        'Settled/Approved','Settled/Rejected',
        'Balance Returned','Overdue Collected'
      );
END;
GO


-- -----------------------------------------------------------------------------
-- 18. usp_SetJobPettyCashSettled
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_SetJobPettyCashSettled', 'P') IS NOT NULL DROP PROCEDURE usp_SetJobPettyCashSettled;
GO
CREATE PROCEDURE usp_SetJobPettyCashSettled
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Jobs SET pettyCashStatus = 'Settled' WHERE jobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 19. usp_UpdatePettyCashAssignmentStatus
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdatePettyCashAssignmentStatus', 'P') IS NOT NULL DROP PROCEDURE usp_UpdatePettyCashAssignmentStatus;
GO
CREATE PROCEDURE usp_UpdatePettyCashAssignmentStatus
    @AssignmentId INT,
    @Status       NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PettyCashAssignments SET status = @Status WHERE assignmentId = @AssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 20. usp_GetPettyCashAssignmentAmounts
--     Used by recalculateStatus()
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPettyCashAssignmentAmounts', 'P') IS NOT NULL DROP PROCEDURE usp_GetPettyCashAssignmentAmounts;
GO
CREATE PROCEDURE usp_GetPettyCashAssignmentAmounts
    @AssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT assignmentId, status, assignedAmount, actualSpent, balanceAmount, overAmount
    FROM PettyCashAssignments
    WHERE assignmentId = @AssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 21. usp_RecalculatePettyCashAssignmentStatus
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_RecalculatePettyCashAssignmentStatus', 'P') IS NOT NULL DROP PROCEDURE usp_RecalculatePettyCashAssignmentStatus;
GO
CREATE PROCEDURE usp_RecalculatePettyCashAssignmentStatus
    @AssignmentId  INT,
    @Status        NVARCHAR(100),
    @BalanceAmount DECIMAL(18,2),
    @OverAmount    DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PettyCashAssignments
    SET status = @Status, balanceAmount = @BalanceAmount, overAmount = @OverAmount
    WHERE assignmentId = @AssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 22. usp_CloseAllPettyCashAssignmentsByJob
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CloseAllPettyCashAssignmentsByJob', 'P') IS NOT NULL DROP PROCEDURE usp_CloseAllPettyCashAssignmentsByJob;
GO
CREATE PROCEDURE usp_CloseAllPettyCashAssignmentsByJob
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PettyCashAssignments SET status = 'Closed'
    WHERE jobId = @JobId AND status <> 'Closed';
END;
GO


-- -----------------------------------------------------------------------------
-- 23. usp_UpdatePettyCashStatusAndClearAmount
--     settlementType: 'BALANCE_RETURN' zeros balanceAmount,
--                     'OVERDUE_COLLECTION' zeros overAmount
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdatePettyCashStatusAndClearAmount', 'P') IS NOT NULL DROP PROCEDURE usp_UpdatePettyCashStatusAndClearAmount;
GO
CREATE PROCEDURE usp_UpdatePettyCashStatusAndClearAmount
    @AssignmentId   INT,
    @Status         NVARCHAR(100),
    @SettlementType VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PettyCashAssignments
    SET status        = @Status,
        balanceAmount = CASE WHEN @SettlementType = 'BALANCE_RETURN'      THEN 0 ELSE balanceAmount END,
        overAmount    = CASE WHEN @SettlementType = 'OVERDUE_COLLECTION'  THEN 0 ELSE overAmount    END
    WHERE assignmentId = @AssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 24. usp_GetPettyCashAssignmentByJobAndUser
--     Optional @AssignmentId filter — pass NULL to get latest for job+user
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPettyCashAssignmentByJobAndUser', 'P') IS NOT NULL DROP PROCEDURE usp_GetPettyCashAssignmentByJobAndUser;
GO
CREATE PROCEDURE usp_GetPettyCashAssignmentByJobAndUser
    @JobId        VARCHAR(50),
    @UserId       VARCHAR(50),
    @AssignmentId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pca.*,
        j.shipmentCategory,
        u1.fullName AS assignedToName,
        u2.fullName AS assignedByName
    FROM PettyCashAssignments pca
    LEFT JOIN Jobs  j  ON pca.jobId      = j.jobId
    LEFT JOIN Users u1 ON pca.assignedTo = u1.userId
    LEFT JOIN Users u2 ON pca.assignedBy = u2.userId
    WHERE pca.jobId      = @JobId
      AND pca.assignedTo = @UserId
      AND (@AssignmentId IS NULL OR pca.assignmentId = @AssignmentId)
    ORDER BY pca.assignedDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 25. usp_GetOtherAssignmentsPredefinedItems
--     Returns predefined items from OTHER assignments for the same job
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetOtherAssignmentsPredefinedItems', 'P') IS NOT NULL DROP PROCEDURE usp_GetOtherAssignmentsPredefinedItems;
GO
CREATE PROCEDURE usp_GetOtherAssignmentsPredefinedItems
    @JobId        VARCHAR(50),
    @AssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT si.*,
        u.fullName AS paidByName,
        u.email    AS paidByEmail,
        pca.assignedTo AS assignmentUserId
    FROM PettyCashSettlementItems si
    LEFT  JOIN Users u ON si.paidBy = u.userId
    INNER JOIN PettyCashAssignments pca ON si.assignmentId = pca.assignmentId
    WHERE pca.jobId        = @JobId
      AND si.assignmentId <> @AssignmentId
      AND si.isCustomItem  = 0
    ORDER BY si.settlementItemId;
END;
GO


-- -----------------------------------------------------------------------------
-- 26. usp_UpdateSettlementItem
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdateSettlementItem', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateSettlementItem;
GO
CREATE PROCEDURE usp_UpdateSettlementItem
    @ItemId     INT,
    @ItemName   NVARCHAR(500),
    @ActualCost DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PettyCashSettlementItems
    SET itemName = @ItemName, actualCost = @ActualCost
    OUTPUT INSERTED.*
    WHERE settlementItemId = @ItemId;
END;
GO


-- -----------------------------------------------------------------------------
-- 27. usp_DeleteSettlementItemById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeleteSettlementItemById', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteSettlementItemById;
GO
CREATE PROCEDURE usp_DeleteSettlementItemById
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM PettyCashSettlementItems WHERE settlementItemId = @ItemId;
END;
GO


-- -----------------------------------------------------------------------------
-- 28. usp_RecalculatePettyCashAssignmentTotals
--     Recalculates actualSpent, balance, over, and status from settlement items
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_RecalculatePettyCashAssignmentTotals', 'P') IS NOT NULL DROP PROCEDURE usp_RecalculatePettyCashAssignmentTotals;
GO
CREATE PROCEDURE usp_RecalculatePettyCashAssignmentTotals
    @AssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ActualSpent   DECIMAL(18,2);
    DECLARE @AssignedAmount DECIMAL(18,2);
    DECLARE @BalanceAmount  DECIMAL(18,2);
    DECLARE @OverAmount     DECIMAL(18,2);
    DECLARE @NewStatus      NVARCHAR(100);

    SELECT @ActualSpent    = ISNULL(SUM(actualCost), 0)
    FROM PettyCashSettlementItems WHERE assignmentId = @AssignmentId;

    SELECT @AssignedAmount = assignedAmount
    FROM PettyCashAssignments WHERE assignmentId = @AssignmentId;

    SET @BalanceAmount = CASE WHEN @AssignedAmount > @ActualSpent THEN @AssignedAmount - @ActualSpent ELSE 0 END;
    SET @OverAmount    = CASE WHEN @ActualSpent > @AssignedAmount THEN @ActualSpent - @AssignedAmount ELSE 0 END;
    SET @NewStatus     = CASE
                           WHEN @BalanceAmount > 0 THEN 'Balance To Be Return'
                           WHEN @OverAmount    > 0 THEN 'Over Due'
                           ELSE 'Settled'
                         END;

    UPDATE PettyCashAssignments
    SET actualSpent = @ActualSpent, balanceAmount = @BalanceAmount,
        overAmount  = @OverAmount,  status        = @NewStatus
    WHERE assignmentId = @AssignmentId;

    SELECT @ActualSpent AS actualSpent, @BalanceAmount AS balanceAmount,
           @OverAmount  AS overAmount,  @NewStatus     AS status;
END;
GO


-- -----------------------------------------------------------------------------
-- 29. usp_CreateSubPettyCashAssignment
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreateSubPettyCashAssignment', 'P') IS NOT NULL DROP PROCEDURE usp_CreateSubPettyCashAssignment;
GO
CREATE PROCEDURE usp_CreateSubPettyCashAssignment
    @JobId              VARCHAR(50),
    @AssignedTo         VARCHAR(50),
    @AssignedBy         VARCHAR(50),
    @AssignedAmount     DECIMAL(18,2),
    @Notes              NVARCHAR(MAX),
    @GroupId            NVARCHAR(200),
    @ParentAssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO PettyCashAssignments
        (jobId, assignedTo, assignedBy, assignedAmount, notes, groupId, parentAssignmentId, isMainAssignment)
    OUTPUT INSERTED.*
    VALUES
        (@JobId, @AssignedTo, @AssignedBy, @AssignedAmount, @Notes, @GroupId, @ParentAssignmentId, 0);
END;
GO


-- -----------------------------------------------------------------------------
-- 30. usp_GetMainPettyCashAssignments
--     @UserId: optional filter — pass NULL for all
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetMainPettyCashAssignments', 'P') IS NOT NULL DROP PROCEDURE usp_GetMainPettyCashAssignments;
GO
CREATE PROCEDURE usp_GetMainPettyCashAssignments
    @UserId VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pca.*,
        ISNULL(pca.groupId, pca.jobId + '_' + pca.assignedTo) AS groupId,
        j.shipmentCategory, j.customerId,
        u1.fullName AS assignedToName,
        u2.fullName AS assignedByName
    FROM PettyCashAssignments pca
    LEFT JOIN Jobs  j  ON pca.jobId      = j.jobId
    LEFT JOIN Users u1 ON pca.assignedTo = u1.userId
    LEFT JOIN Users u2 ON pca.assignedBy = u2.userId
    WHERE pca.isMainAssignment = 1
      AND (@UserId IS NULL OR pca.assignedTo = @UserId)
    ORDER BY pca.assignedDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 31. usp_GetSubPettyCashAssignments
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetSubPettyCashAssignments', 'P') IS NOT NULL DROP PROCEDURE usp_GetSubPettyCashAssignments;
GO
CREATE PROCEDURE usp_GetSubPettyCashAssignments
    @ParentAssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pca.*, u2.fullName AS assignedByName
    FROM PettyCashAssignments pca
    LEFT JOIN Users u2 ON pca.assignedBy = u2.userId
    WHERE pca.parentAssignmentId = @ParentAssignmentId
    ORDER BY pca.assignedDate ASC;
END;
GO


-- -----------------------------------------------------------------------------
-- 32. usp_GetTotalPettyCashAssignedAmount
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetTotalPettyCashAssignedAmount', 'P') IS NOT NULL DROP PROCEDURE usp_GetTotalPettyCashAssignedAmount;
GO
CREATE PROCEDURE usp_GetTotalPettyCashAssignedAmount
    @MainAssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(SUM(assignedAmount), 0) AS totalAmount
    FROM PettyCashAssignments
    WHERE assignmentId = @MainAssignmentId OR parentAssignmentId = @MainAssignmentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 33. usp_GetPettyCashAssignmentsByDateRange
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPettyCashAssignmentsByDateRange', 'P') IS NOT NULL DROP PROCEDURE usp_GetPettyCashAssignmentsByDateRange;
GO
CREATE PROCEDURE usp_GetPettyCashAssignmentsByDateRange
    @FromDate VARCHAR(10),
    @ToDate   VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    WITH SettlementTotals AS (
        SELECT assignmentId, SUM(actualCost) AS totalSettled
        FROM PettyCashSettlementItems GROUP BY assignmentId
    ),
    GroupedAssignments AS (
        SELECT
            MIN(pca.assignmentId) AS assignmentId,
            pca.jobId, pca.assignedTo,
            MIN(pca.assignedBy)   AS assignedBy,
            SUM(pca.assignedAmount) AS assignedAmount,
            MIN(pca.assignedDate)   AS assignedDate,
            CASE
                WHEN COUNT(DISTINCT pca.status) = 1 THEN MIN(pca.status)
                WHEN SUM(CASE WHEN pca.status LIKE 'Settled%' THEN 1 ELSE 0 END) = COUNT(*) THEN 'Settled'
                ELSE 'Mixed'
            END AS status,
            MAX(pca.settlementDate)       AS settlementDate,
            SUM(ISNULL(pca.actualSpent,0)) AS actualSpent,
            STRING_AGG(ISNULL(pca.notes,''), '; ') AS notes,
            MIN(ISNULL(pca.groupId, pca.jobId + '_' + pca.assignedTo)) AS groupId,
            MIN(j.shipmentCategory) AS shipmentCategory,
            MIN(j.customerId)       AS customerId,
            MIN(c.Name)             AS customerName,
            MIN(u1.fullName)        AS assignedToName,
            MIN(u2.fullName)        AS assignedByName,
            SUM(ISNULL(st.totalSettled,0)) AS settledAmount,
            COUNT(*) AS assignmentCount
        FROM PettyCashAssignments pca
        LEFT JOIN Jobs  j  ON pca.jobId      = j.jobId
        LEFT JOIN Customers c ON j.customerId = c.customerId
        LEFT JOIN Users u1 ON pca.assignedTo = u1.userId
        LEFT JOIN Users u2 ON pca.assignedBy = u2.userId
        LEFT JOIN SettlementTotals st ON pca.assignmentId = st.assignmentId
        WHERE CONVERT(DATE, pca.assignedDate) BETWEEN CONVERT(DATE, @FromDate) AND CONVERT(DATE, @ToDate)
        GROUP BY pca.jobId, pca.assignedTo
    )
    SELECT *,
        CASE WHEN settledAmount < assignedAmount THEN assignedAmount - settledAmount ELSE 0 END AS balanceAmount,
        CASE WHEN settledAmount > assignedAmount THEN settledAmount - assignedAmount ELSE 0 END AS overAmount
    FROM GroupedAssignments
    ORDER BY jobId ASC, assignedTo ASC;
END;
GO
