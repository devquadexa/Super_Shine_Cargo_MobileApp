import 'package:dio/dio.dart';
import 'client.dart';
import '../models/user.dart';

class AuthService {
  /// POST /api/auth/login
  /// Returns { token, user }
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await apiClient.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Login failed. Please try again.';
      throw Exception(message);
    }
  }

  /// GET /api/auth/me — fetch current user profile
  Future<User> getMe() async {
    try {
      final response = await apiClient.get('/auth/me');
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Failed to fetch user.';
      throw Exception(message);
    }
  }

  /// GET /api/auth/users — fetch all users (Admin/Manager)
  Future<List<User>> getUsers() async {
    try {
      final response = await apiClient.get('/auth/users');
      final list = response.data as List<dynamic>;
      return list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Failed to fetch users.';
      throw Exception(message);
    }
  }

  /// POST /api/auth/register — create a new user (Super Admin only)
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String role,
  }) async {
    try {
      final response = await apiClient.post('/auth/register', data: {
        'username': username,
        'password': password,
        'fullName': fullName,
        'email': email,
        'role': role,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Failed to create user.';
      throw Exception(message);
    }
  }
}
