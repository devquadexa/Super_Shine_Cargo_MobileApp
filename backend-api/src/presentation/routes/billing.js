/**
 * Billing Routes (Clean Architecture)
 */
const express = require('express');
const jwt = require('jsonwebtoken');
const { auth, checkRole, JWT_SECRET } = require('../../middleware/auth');
const container = require('../../infrastructure/di/container');
const BillingController = require('../controllers/BillingController');
const ExportBillPDF = require('../../application/use-cases/billing/ExportBillPDF');

const router = express.Router();

// Initialize controller with use cases from DI container
const billingController = new BillingController(
  container.get('createBill'),
  container.get('getAllBills'),
  container.get('getBillById'),
  container.get('markBillAsPaid'),
  container.get('applyPartialPayment')
);

// Routes
router.post('/', auth, checkRole('Admin', 'Super Admin', 'Manager'), (req, res) =>
  billingController.create(req, res)
);
router.get('/', auth, (req, res) =>
  billingController.getAll(req, res)
);

// Single bill PDF — supports token via query param for browser access
router.get('/:id/pdf', async (req, res) => {
  try {
    // Support auth via header OR query parameter (for browser URL access)
    const headerToken = req.header('Authorization')?.replace('Bearer ', '');
    const queryToken = req.query.token;
    const token = headerToken || queryToken;

    if (!token) {
      return res.status(401).json({ message: 'Please authenticate' });
    }

    try {
      jwt.verify(token, JWT_SECRET);
    } catch (e) {
      return res.status(401).json({ message: 'Invalid or expired token' });
    }

    const billRepository = container.get('billRepository');
    const customerRepository = container.get('customerRepository');
    const jobRepository = container.get('jobRepository');
    const exportBillPDF = new ExportBillPDF(billRepository, customerRepository, jobRepository);
    const pdfBuffer = await exportBillPDF.execute(req.params.id);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="Invoice-${req.params.id}.pdf"`);
    res.send(pdfBuffer);
  } catch (error) {
    console.error('Error generating bill PDF:', error);
    res.status(error.message === 'Bill not found' ? 404 : 500)
      .json({ message: error.message || 'Error generating PDF' });
  }
});

router.get('/:id', auth, (req, res) =>
  billingController.getById(req, res)
);
router.patch('/:id/pay', auth, checkRole('Admin', 'Super Admin', 'Manager'), (req, res) =>
  billingController.markAsPaid(req, res)
);
router.patch('/:id/partial-pay', auth, checkRole('Admin', 'Super Admin', 'Manager'), (req, res) =>
  billingController.partialPayment(req, res)
);
router.put('/:id', auth, checkRole('Admin', 'Super Admin', 'Manager'), (req, res) =>
  billingController.markAsPaid(req, res)
);

// Invoice Report Routes
router.get('/report/invoices/export/pdf', auth, async (req, res) => {
  try {
    const { fromDate, toDate, status } = req.query;
    const ExportInvoiceReportPDF = require('../../application/use-cases/billing/ExportInvoiceReportPDF');
    const billRepository = container.get('billRepository');
    const exportPDF = new ExportInvoiceReportPDF(billRepository);
    const pdfBuffer = await exportPDF.execute(fromDate, toDate, status || 'All');

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=Invoice_Report_${fromDate}_to_${toDate}.pdf`);
    res.send(pdfBuffer);
  } catch (error) {
    console.error('Error generating invoice report PDF:', error);
    res.status(500).json({ error: error.message });
  }
});

router.get('/report/invoices/export/excel', auth, async (req, res) => {
  try {
    const { fromDate, toDate, status } = req.query;
    const ExportInvoiceReportExcel = require('../../application/use-cases/billing/ExportInvoiceReportExcel');
    const billRepository = container.get('billRepository');
    const exportExcel = new ExportInvoiceReportExcel(billRepository);
    const excelBuffer = await exportExcel.execute(fromDate, toDate, status || 'All');

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=Invoice_Report_${fromDate}_to_${toDate}.xlsx`);
    res.send(excelBuffer);
  } catch (error) {
    console.error('Error generating invoice report Excel:', error);
    res.status(500).json({ error: error.message });
  }
});

// Pending Payments Report Routes
router.get('/report/pending-payments', auth, async (req, res) => {
  try {
    const { fromDate, toDate, showOverdueOnly } = req.query;
    const getPendingPaymentsReport = container.get('getPendingPaymentsReport');
    const result = await getPendingPaymentsReport.execute(fromDate, toDate, showOverdueOnly === 'true');
    res.json(result);
  } catch (error) {
    console.error('Error fetching pending payments report:', error);
    res.status(500).json({ error: error.message });
  }
});

router.get('/report/pending-payments/export/pdf', auth, async (req, res) => {
  try {
    const { fromDate, toDate, showOverdueOnly } = req.query;
    const exportPendingPaymentsReportPDF = container.get('exportPendingPaymentsReportPDF');
    const pdfBuffer = await exportPendingPaymentsReportPDF.execute(fromDate, toDate, showOverdueOnly === 'true');
    
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=Pending_Payments_Report_${fromDate}_to_${toDate}.pdf`);
    res.send(pdfBuffer);
  } catch (error) {
    console.error('Error generating PDF:', error);
    res.status(500).json({ error: error.message });
  }
});

router.get('/report/pending-payments/export/excel', auth, async (req, res) => {
  try {
    const { fromDate, toDate, showOverdueOnly } = req.query;
    const exportPendingPaymentsReportExcel = container.get('exportPendingPaymentsReportExcel');
    const excelBuffer = await exportPendingPaymentsReportExcel.execute(fromDate, toDate, showOverdueOnly === 'true');
    
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=Pending_Payments_Report_${fromDate}_to_${toDate}.xlsx`);
    res.send(excelBuffer);
  } catch (error) {
    console.error('Error generating Excel:', error);
    res.status(500).json({ error: error.message });
  }
});

router.put('/:id', auth, checkRole('Admin', 'Super Admin', 'Manager'), (req, res) => 
  billingController.markAsPaid(req, res)
);

module.exports = router;
