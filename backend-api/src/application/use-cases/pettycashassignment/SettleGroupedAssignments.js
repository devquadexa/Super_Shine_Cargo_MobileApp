class SettleGroupedAssignments {
  constructor(pettyCashAssignmentRepository) {
    this.pettyCashAssignmentRepository = pettyCashAssignmentRepository;
  }

  async execute(groupId, settlementData) {
    // Get all assignments in this group
    const allAssignments = await this.pettyCashAssignmentRepository.getAll();
    const groupAssignments = allAssignments.filter(a => 
      (a.groupId || `${a.jobId}_${a.assignedTo}`) === groupId
    );

    if (groupAssignments.length === 0) {
      throw new Error('No assignments found for this group');
    }

    // Calculate group totals
    const totalAssigned = groupAssignments.reduce((sum, a) => sum + parseFloat(a.assignedAmount || 0), 0);
    const totalSpent = (settlementData.items || []).reduce((sum, item) => sum + parseFloat(item.actualCost || 0), 0);

    // Determine group-level status based on total amounts
    let groupStatus = 'Settled';
    if (totalSpent === 0 && totalAssigned > 0) {
      groupStatus = 'Full Petty Cash Returned';
    } else if (totalAssigned > totalSpent) {
      groupStatus = 'Balance To Be Return';
    } else if (totalSpent > totalAssigned) {
      groupStatus = 'Over Due';
    }

    // Settle the FIRST assignment with all items, set others to same status with 0 items
    const results = [];
    const mainAssignmentId = groupAssignments[0].assignmentId;

    for (let i = 0; i < groupAssignments.length; i++) {
      const assignment = groupAssignments[i];
      
      if (i === 0) {
        // First assignment gets all the items
        const result = await this.pettyCashAssignmentRepository.settle(
          assignment.assignmentId,
          settlementData,
          { overrideStatus: groupStatus, groupTotalAssigned: totalAssigned }
        );
        results.push(result);
      } else {
        // Other assignments get settled with empty items but same status
        const result = await this.pettyCashAssignmentRepository.settle(
          assignment.assignmentId,
          { items: [] },
          { overrideStatus: groupStatus, groupTotalAssigned: totalAssigned }
        );
        results.push(result);
      }
    }

    return results;
  }
}

module.exports = SettleGroupedAssignments;
