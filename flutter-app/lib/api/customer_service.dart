import 'package:dio/dio.dart';
import 'client.dart';
import '../models/customer.dart';

class CustomerService {
  /// GET /api/customers
  Future<List<Customer>> getAll() async {
    try {
      final response = await apiClient.get('/customers');
      final list = response.data as List<dynamic>;
      return list.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load customers.');
    }
  }

  /// GET /api/customers/:id
  Future<Customer> getById(String id) async {
    try {
      final response = await apiClient.get('/customers/$id');
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load customer.');
    }
  }

  /// POST /api/customers
  Future<Customer> create(Map<String, dynamic> data) async {
    try {
      final response = await apiClient.post('/customers', data: data);
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to create customer.');
    }
  }

  /// PUT /api/customers/:id
  Future<Customer> update(String id, Map<String, dynamic> data) async {
    try {
      final response = await apiClient.put('/customers/$id', data: data);
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update customer.');
    }
  }

  /// GET /api/customers/categories/all
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await apiClient.get('/customers/categories/all');
      final list = response.data as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load categories.');
    }
  }
}
