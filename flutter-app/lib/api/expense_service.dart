import 'client.dart';

class ExpenseService {
  /// Fetch all expenses with optional filters
  Future<List<Map<String, dynamic>>> getAll({
    String? category,
    String? fromDate,
    String? toDate,
  }) async {
    final params = <String, String>{};
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (fromDate != null && fromDate.isNotEmpty) params['fromDate'] = fromDate;
    if (toDate != null && toDate.isNotEmpty) params['toDate'] = toDate;

    final query = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';
    final response = await apiClient.get('/other-expenses$query');
    return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Create a new expense
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final response = await apiClient.post('/other-expenses', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Update an existing expense
  Future<Map<String, dynamic>> update(String expenseId, Map<String, dynamic> data) async {
    final response = await apiClient.put('/other-expenses/$expenseId', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Delete an expense
  Future<void> delete(String expenseId) async {
    await apiClient.delete('/other-expenses/$expenseId');
  }
}
