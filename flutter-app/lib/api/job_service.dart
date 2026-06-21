import 'package:dio/dio.dart';
import 'client.dart';
import '../models/job.dart';

class JobService {
  Future<List<Job>> getAll() async {
    try {
      final response = await apiClient.get('/jobs');
      final list = response.data as List<dynamic>;
      return list.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load jobs.');
    }
  }

  Future<Job> getById(String id) async {
    try {
      final response = await apiClient.get('/jobs/$id');
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load job.');
    }
  }

  Future<void> create(Map<String, dynamic> data) async {
    try {
      await apiClient.post('/jobs', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to create job.');
    }
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    try {
      await apiClient.put('/jobs/$id', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update job.');
    }
  }

  /// Assign multiple users to a job
  Future<void> assignUsersToJob(String jobId, List<String> userIds) async {
    try {
      await apiClient.post('/job-assignments/jobs/$jobId/assign-users', data: {
        'userIds': userIds,
        'notes': 'Assigned from mobile app',
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to assign users.');
    }
  }

  // ── Office Pay Items ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getOfficePayItems(String jobId) async {
    try {
      final r = await apiClient.get('/office-pay-items/job/$jobId');
      return (r.data as List<dynamic>).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load office pay items.');
    }
  }

  Future<void> createOfficePayItem(Map<String, dynamic> data) async {
    try {
      await apiClient.post('/office-pay-items', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to create office pay item.');
    }
  }

  Future<void> deleteOfficePayItem(String id) async {
    try {
      await apiClient.delete('/office-pay-items/$id');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete office pay item.');
    }
  }

  // ── Advance Payments ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAdvancePayments(String jobId) async {
    try {
      final r = await apiClient.get('/jobs/$jobId/advance-payments');
      return (r.data as List<dynamic>).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load advance payments.');
    }
  }

  Future<void> addAdvancePayment(String jobId, Map<String, dynamic> data) async {
    try {
      await apiClient.post('/jobs/$jobId/advance-payments', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to add advance payment.');
    }
  }

  Future<void> deleteAdvancePayment(String jobId, String paymentId) async {
    try {
      await apiClient.delete('/jobs/$jobId/advance-payments/$paymentId');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete advance payment.');
    }
  }

  // ── Petty Cash Assignments ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPettyCashByJob(String jobId) async {
    try {
      final r = await apiClient.get('/petty-cash-assignments/job/$jobId/all');
      return (r.data as List<dynamic>).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load petty cash.');
    }
  }

  /// Get petty cash for the current user's role:
  /// - Admin/Manager: uses /all endpoint (returns array)
  /// - Waff Clerk: uses /my endpoint filtered by jobId, merged by groupId
  Future<List<Map<String, dynamic>>> getPettyCashByJobForUser(String jobId, String userRole) async {
    try {
      if (['Admin', 'Super Admin', 'Manager'].contains(userRole)) {
        final r = await apiClient.get('/petty-cash-assignments/job/$jobId/all');
        return _mergeAssignmentsByGroup((r.data as List<dynamic>).cast<Map<String, dynamic>>());
      } else {
        // Waff Clerk — get all own assignments and filter by jobId
        final r = await apiClient.get('/petty-cash-assignments/my');
        final all = (r.data as List<dynamic>).cast<Map<String, dynamic>>();
        final forJob = all.where((a) => a['jobId']?.toString() == jobId).toList();
        return _mergeAssignmentsByGroup(forJob);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw Exception(e.response?.data?['message'] ?? 'Failed to load petty cash.');
    }
  }

  /// Merge multiple assignments for the same user+group into a single card
  List<Map<String, dynamic>> _mergeAssignmentsByGroup(List<Map<String, dynamic>> assignments) {
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final a in assignments) {
      final key = a['groupId']?.toString() ?? '${a['assignedTo']}_${a['jobId']}';
      if (grouped.containsKey(key)) {
        final existing = grouped[key]!;
        existing['assignedAmount'] = (double.tryParse(existing['assignedAmount']?.toString() ?? '0') ?? 0) +
            (double.tryParse(a['assignedAmount']?.toString() ?? '0') ?? 0);
        existing['actualSpent'] = (double.tryParse(existing['actualSpent']?.toString() ?? '0') ?? 0) +
            (double.tryParse(a['actualSpent']?.toString() ?? '0') ?? 0);
        // Use the most advanced status (settled > assigned)
        final aStatus = a['status']?.toString().toLowerCase() ?? '';
        final existingStatus = existing['status']?.toString().toLowerCase() ?? '';
        if (existingStatus == 'assigned' || existingStatus == 'pending') {
          existing['status'] = a['status'];
        }
        // Track all assignment IDs
        existing['_assignmentIds'] = [...(existing['_assignmentIds'] as List? ?? [existing['assignmentId']]), a['assignmentId']];
        // Use the settled assignment's ID as primary
        if (aStatus != 'assigned' && aStatus != 'pending') {
          existing['assignmentId'] = a['assignmentId'];
        }
        // Merge settlement items
        final existingItems = existing['settlementItems'] as List? ?? [];
        final newItems = a['settlementItems'] as List? ?? [];
        existing['settlementItems'] = [...existingItems, ...newItems];
      } else {
        grouped[key] = Map<String, dynamic>.from(a);
        grouped[key]!['_assignmentIds'] = [a['assignmentId']];
      }
    }
    return grouped.values.toList();
  }

  /// Get the current user's petty cash assignment for a specific job
  Future<Map<String, dynamic>?> getMyPettyCashByJob(String jobId) async {
    try {
      final r = await apiClient.get('/petty-cash-assignments/job/$jobId');
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(e.response?.data?['message'] ?? 'Failed to load petty cash assignment.');
    }
  }

  /// Get settlement items for a specific assignment
  Future<List<Map<String, dynamic>>> getSettlementItems(int assignmentId) async {
    try {
      final r = await apiClient.get('/petty-cash-assignments/$assignmentId/settlement-items');
      return (r.data as List<dynamic>).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load settlement items.');
    }
  }

  /// Get assignment details for a job including readOnlyPredefinedItems from other assignments
  Future<Map<String, dynamic>?> getJobAssignmentWithReadOnly(String jobId, int assignmentId) async {
    try {
      final r = await apiClient.get('/petty-cash-assignments/job/$jobId?assignmentId=$assignmentId');
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(e.response?.data?['message'] ?? 'Failed to load assignment details.');
    }
  }

  /// Get pay item templates by shipment category
  Future<List<Map<String, dynamic>>> getPayItemTemplates(String category) async {
    try {
      final r = await apiClient.get('/pay-item-templates/category/${Uri.encodeComponent(category)}');
      return (r.data as List<dynamic>).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw Exception(e.response?.data?['message'] ?? 'Failed to load templates.');
    }
  }

  /// Settle a petty cash assignment
  Future<Map<String, dynamic>> settlePettyCash(int assignmentId, List<Map<String, dynamic>> items) async {
    try {
      final r = await apiClient.post(
        '/petty-cash-assignments/$assignmentId/settle',
        data: {'items': items},
      );
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to settle petty cash.');
    }
  }

  /// Settle a grouped petty cash assignment (settles all assignments in the group)
  Future<Map<String, dynamic>> settleGroupPettyCash(String groupId, List<Map<String, dynamic>> items) async {
    try {
      final r = await apiClient.post(
        '/petty-cash-assignments/group/${Uri.encodeComponent(groupId)}/settle',
        data: {'items': items},
      );
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to settle petty cash.');
    }
  }

  /// Update a settlement item
  Future<void> updateSettlementItem(int assignmentId, int itemId, String itemName, double actualCost) async {
    try {
      await apiClient.patch(
        '/petty-cash-assignments/$assignmentId/settlement-items/$itemId',
        data: {'itemName': itemName, 'actualCost': actualCost},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update item.');
    }
  }

  /// Delete a settlement item
  Future<void> deleteSettlementItem(int assignmentId, int itemId) async {
    try {
      await apiClient.delete('/petty-cash-assignments/$assignmentId/settlement-items/$itemId');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete item.');
    }
  }

  /// Create a new petty cash assignment for a job
  Future<Map<String, dynamic>> createPettyCashAssignment({
    required String jobId,
    required String assignedTo,
    required double assignedAmount,
    String? notes,
  }) async {
    try {
      final r = await apiClient.post(
        '/petty-cash-assignments',
        data: {
          'jobId': jobId,
          'assignedTo': assignedTo,
          'assignedAmount': assignedAmount,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to create petty cash assignment.');
    }
  }
}
