import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Android emulator routes 10.0.2.2 → host machine's localhost
// Change to your machine's local IP (e.g. 192.168.1.x) for physical device testing
const String _baseUrl = 'http://10.0.2.2:5000/api';

const _storage = FlutterSecureStorage();

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Request interceptor — attach JWT token to every request
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          // 401 means token expired or invalid — caller handles redirect
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;
}

// Convenience getter used throughout the app
final apiClient = ApiClient().dio;
