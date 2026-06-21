import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/auth_service.dart';
import '../models/user.dart';

const _storage = FlutterSecureStorage();

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = true; // true on startup while checking stored token
  String? _error;

  final AuthService _authService = AuthService();

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _restoreSession();
  }

  /// On app start, check if a token is stored and re-validate it
  Future<void> _restoreSession() async {
    final token = await _storage.read(key: 'token');
    if (token != null) {
      try {
        _user = await _authService.getMe();
      } catch (_) {
        // Token is invalid or expired — clear it
        await _storage.delete(key: 'token');
        _user = null;
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Login with username + password
  Future<void> login(String username, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.login(username, password);
      final token = result['token'] as String;
      final userData = result['user'] as Map<String, dynamic>;

      // Persist token securely
      await _storage.write(key: 'token', value: token);
      _user = User.fromJson(userData);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logout — clear stored token and user state
  Future<void> logout() async {
    await _storage.delete(key: 'token');
    _user = null;
    notifyListeners();
  }
}
