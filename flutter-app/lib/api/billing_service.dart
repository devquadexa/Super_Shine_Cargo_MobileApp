import 'package:dio/dio.dart';
import 'client.dart';

class BillingService {
  // ── Bills ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBills({String? paymentStatus}) async {
    try {
      final params = paymentStatus != null ? {'paymentStatus': paymentStatus} : null;
      final r = await apiClient.get('/billing', queryParameters: params);
      return (r.data as List<dynamic>).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load bills.');
    }
  }

  Future<Map<String, dynamic>> getBillById(String billId) async {
    try {
      final r = await apiClient.get('/billing/$billId');
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load bill.');
    }
  }

  /// Download bill as PDF
  Future<List<int>> getBillPDF(String billId) async {
    try {
      final r = await apiClient.get(
        '/billing/$billId/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      return r.data as List<int>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to generate PDF.');
    }
  }

  /// Generate invoice for a job. Payload: {jobId, customerId, actualCost, billingAmount}
  Future<Map<String, dynamic>> createBill(Map<String, dynamic> data) async {
    try {
      final r = await apiClient.post('/billing', data: data);
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to generate invoice.');
    }
  }

  /// Mark a bill as fully paid
  Future<Map<String, dynamic>> markAsPaid(String billId, Map<String, dynamic> paymentDetails) async {
    try {
      final r = await apiClient.patch('/billing/$billId/pay', data: paymentDetails);
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to mark as paid.');
    }
  }

  /// Apply a partial payment
  Future<Map<String, dynamic>> applyPartialPayment(String billId, double amount, Map<String, dynamic> details) async {
    try {
      final r = await apiClient.patch('/billing/$billId/partial-pay', data: {
        'paymentAmount': amount,
        ...details,
      });
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to apply payment.');
    }
  }

  // ── Pay Items (job pay items from jobs route) ─────────────────────────────────

  Future<List<Map<String, dynamic>>> getOfficePayItemsByJob(String jobId) async {
    try {
      final r = await apiClient.get('/office-pay-items/job/$jobId');
      return (r.data as List<dynamic>).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load pay items.');
    }
  }

  Future<void> updateJobPayItems(String jobId, List<Map<String, dynamic>> payItems) async {
    try {
      await apiClient.put('/jobs/$jobId/pay-items', data: {'payItems': payItems});
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update pay items.');
    }
  }

  // ── Invoice Review ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getInvoiceReviews() async {
    try {
      final r = await apiClient.get('/invoice-reviews');
      return (r.data as List<dynamic>).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load reviews.');
    }
  }

  Future<Map<String, dynamic>> sendInvoiceReview(Map<String, dynamic> data) async {
    try {
      final r = await apiClient.post('/invoice-reviews', data: data);
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to send review.');
    }
  }

  Future<void> approveInvoiceReview(String reviewId) async {
    try {
      await apiClient.patch('/invoice-reviews/$reviewId/approve');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to approve review.');
    }
  }

  Future<void> rejectInvoiceReview(String reviewId, String reason) async {
    try {
      await apiClient.patch('/invoice-reviews/$reviewId/reject', data: {'rejectionReason': reason});
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to reject review.');
    }
  }
}
