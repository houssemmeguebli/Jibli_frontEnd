import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  Future<void> loadUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authService.getAccessToken();
      if (token != null) {
        final payload = _decodeToken(token);
        _user = User(
          id: await _authService.getUserId() ?? 0,
          email: await _authService.getUserEmail() ?? '',
          phone: await _authService.getUserPhone(),
          fullName: payload['fullName'],
          roles: await _authService.getUserRoles(),
        );
      }
    } catch (e) {
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login({String? email, String? phone, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.login(email: email, phone: phone, password: password);
      await loadUser();
      return true;
    } catch (e) {
      _user = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  Map<String, dynamic> _decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded);
    } catch (e) {
      return {};
    }
  }
}