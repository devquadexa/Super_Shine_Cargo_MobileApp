/**
 * Get Accounting Dashboard Use Case
 * Provides comprehensive financial overview for Super Admin
 */
class GetAccountingDashboard {
  constructor(jobRepository, billRepository, pettyCashAssignmentRepository, customerRepository) {
    this.jobRepository = jobRepository;
    this.billRepository = billRepository;
    this.pettyCashAssignmentRepository = pettyCashAssignmentRepository;
    this.customerRepository = customerRepository;
  }

  async execute() {
    console.log('GetAccountingDashboard - Starting...');
    
    // Get all jobs with their financial data
    const jobs = await this.jobRepository.findAll();
    console.log('GetAccountingDashboard - Found jobs:', jobs.length);
    
    // Get all bills
    const bills = await this.billRepository.findAll();
    console.log('GetAccountingDashboard - Found bills:', bills.length);
    
    // Get all petty cash assignments
    const pettyCashAssignments = await this.pettyCashAssignmentRepository.findAll();
    console.log('GetAccountingDashboard - Found petty cash assignments:', pettyCashAssignments.length);
    
    // Get all customers
    const customers = await this.customerRepository.findAll();
    console.log('GetAccountingDashboard - Found customers:', customers.length);
    
    // Build job-wise financial data
    const jobFinancials = [];
    
    for (const job of jobs) {
      // Get bill for this job
      const jobBills = bills.filter(b => b.jobId === job.jobId);
      const bill = jobBills.length > 0 ? jobBills[0] : null;
      
      // Get ALL petty cash assignments for this job (not just the first one)
      const jobPettyCash = pettyCashAssignments.filter(pc => pc.jobId === job.jobId);
      const totalPettyCashIssued = jobPettyCash.reduce((sum, pc) => sum + (parseFloat(pc.assignedAmount || pc.amount || 0)), 0);
      
      // Calculate actual cost from pay items
      const actualCost = job.payItems ? 
        job.payItems.reduce((sum, item) => sum + (parseFloat(item.actualCost) || 0), 0) : 0;
      
      // Calculate billing amount (use netTotal which accounts for advance payments, fallback to billingAmount)
      const billingAmount = bill ? (parseFloat(bill.netTotal) || parseFloat(bill.billingAmount) || parseFloat(bill.amount) || 0) : 0;
      
      // Amount already paid
      const paidAmount = bill ? (parseFloat(bill.paidAmount) || 0) : 0;
      
      // Remaining outstanding for this bill
      const remainingAmount = billingAmount - paidAmount;
      
      // Calculate profit
      const profit = billingAmount - actualCost;
      
      // Payment status
      const isPaid = bill ? bill.paymentStatus === 'Paid' : false;
      const isPartiallyPaid = bill ? bill.paymentStatus === 'Partially Paid' : false;
      const isOverdue = bill ? bill.isOverdue : false;
      
      // Calculate overdue days
      let overdueDays = 0;
      if (bill && bill.dueDate && !isPaid) {
        const dueDate = new Date(bill.dueDate);
        const today = new Date();
        if (today > dueDate) {
          overdueDays = Math.floor((today - dueDate) / (1000 * 60 * 60 * 24));
        }
      }
      
      // Get customer info
      const customer = customers.find(c => c.customerId === job.customerId);
      
      jobFinancials.push({
        jobId: job.jobId,
        customerId: job.customerId,
        customerName: customer ? customer.name : job.customerId,
        openDate: job.openDate,
        status: job.status,
        pettyCashIssued: totalPettyCashIssued,
        actualCost: actualCost,
        billingAmount: billingAmount,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        profit: profit,
        isPaid: isPaid,
        isPartiallyPaid: isPartiallyPaid,
        isOverdue: isOverdue,
        overdueDays: overdueDays,
        invoiceDate: bill ? bill.invoiceDate : null,
        dueDate: bill ? bill.dueDate : null,
        billId: bill ? bill.billId : null
      });
    }
    
    // Calculate customer-wise outstanding
    const customerOutstanding = {};
    
    for (const customer of customers) {
      const customerJobs = jobFinancials.filter(j => j.customerId === customer.customerId);
      const unpaidJobs = customerJobs.filter(j => !j.isPaid && j.billingAmount > 0);
      
      // Use remainingAmount (billing - paid) instead of full billingAmount
      const totalOutstanding = unpaidJobs.reduce((sum, job) => sum + job.remainingAmount, 0);
      const overdueAmount = unpaidJobs
        .filter(j => j.isOverdue)
        .reduce((sum, job) => sum + job.remainingAmount, 0);
      
      if (totalOutstanding > 0) {
        customerOutstanding[customer.customerId] = {
          customerId: customer.customerId,
          customerName: customer.name,
          totalOutstanding: totalOutstanding,
          overdueAmount: overdueAmount,
          unpaidJobsCount: unpaidJobs.length,
          overdueJobsCount: unpaidJobs.filter(j => j.isOverdue).length,
          creditPeriodDays: customer.creditPeriodDays || 30
        };
      }
    }
    
    // Calculate summary statistics
    const unpaidJobs = jobFinancials.filter(j => !j.isPaid && !j.isPartiallyPaid && j.billingAmount > 0);
    const partiallyPaidJobs = jobFinancials.filter(j => j.isPartiallyPaid);
    const summary = {
      totalJobs: jobs.length,
      totalPettyCashIssued: jobFinancials.reduce((sum, j) => sum + j.pettyCashIssued, 0),
      totalActualCost: jobFinancials.reduce((sum, j) => sum + j.actualCost, 0),
      totalBillingAmount: jobFinancials.reduce((sum, j) => sum + j.billingAmount, 0),
      totalProfit: jobFinancials.reduce((sum, j) => sum + j.profit, 0),
      totalPaid: jobFinancials.reduce((sum, j) => sum + j.paidAmount, 0),
      totalOutstanding: unpaidJobs.reduce((sum, j) => sum + j.remainingAmount, 0),
      totalPartiallyPaid: partiallyPaidJobs.reduce((sum, j) => sum + j.remainingAmount, 0),
      totalOverdue: jobFinancials.filter(j => j.isOverdue).reduce((sum, j) => sum + j.remainingAmount, 0),
      paidJobsCount: jobFinancials.filter(j => j.isPaid).length,
      unpaidJobsCount: unpaidJobs.length,
      partiallyPaidJobsCount: partiallyPaidJobs.length,
      overdueJobsCount: jobFinancials.filter(j => j.isOverdue).length
    };
    
    console.log('GetAccountingDashboard - Summary:', summary);
    
    return {
      summary,
      jobFinancials,
      customerOutstanding: Object.values(customerOutstanding)
    };
  }
}

module.exports = GetAccountingDashboard;
