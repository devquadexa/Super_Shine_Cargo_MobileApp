import 'client.dart';

class AccountingService {
  /// Fetch the full accounting dashboard data
  Future<Map<String, dynamic>> getDashboard() async {
    final response = await apiClient.get('/accounting/dashboard');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch all payments
  Future<List<Map<String, dynamic>>> getAllPayments() async {
    final response = await apiClient.get('/payments/all');
    return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
