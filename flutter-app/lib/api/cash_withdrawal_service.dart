import 'client.dart';

class CashWithdrawalService {
  /// Fetch all cash withdrawals/deposits
  Future<List<Map<String, dynamic>>> getAll() async {
    final response = await apiClient.get('/cash-withdrawals');
    return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Create a new cash withdrawal or deposit
  Future<Map<String, dynamic>> create({
    required double amount,
    required String bankName,
    required String withdrawalDate,
    required String transactionType,
    String? notes,
  }) async {
    final response = await apiClient.post('/cash-withdrawals', data: {
      'amount': amount,
      'bankName': bankName,
      'withdrawalDate': withdrawalDate,
      'transactionType': transactionType,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }
}
