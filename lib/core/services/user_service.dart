import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class UserService {
  static const String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============================================================================
  // GET ALL USERS
  // ============================================================================
  Future<List<Map<String, dynamic>>> getAllUsers({int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? List<Map<String, dynamic>>.from(data) : [];
      }

      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getAllUsers(retry: 1);
      }

      if (response.statusCode == 403) {
        throw Exception('Permission denied');
      }

      throw Exception('Failed to load users: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // GET USER BY ID
  // ============================================================================
  Future<Map<String, dynamic>?> getUserById(int id, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getUserById(id, retry: 1);
      }
      if (response.statusCode == 403) {
        throw Exception('Permission denied');
      }

      throw Exception('Failed to load user: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // UPDATE USER - FIXED & CLEAN
  // ============================================================================
  Future<Map<String, dynamic>?> updateUser(int id, Map<String, dynamic> user, {int retry = 0}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(user),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return updateUser(id, user, retry: 1);
      }
      if (response.statusCode == 403) {
        throw Exception('Forbidden: Cannot update user');
      }

      throw Exception('Update failed: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // DELETE USER
  // ============================================================================
  Future<bool> deleteUser(int id, {int retry = 0}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 204 || response.statusCode == 200) return true;
      if (response.statusCode == 404) return false;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return deleteUser(id, retry: 1);
      }
      if (response.statusCode == 403) {
        throw Exception('Only ADMIN can delete users');
      }

      throw Exception('Delete failed: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // GET USERS BY ROLE
  // ============================================================================
  Future<List<Map<String, dynamic>>> getUsersByUserRole(String userRole, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/userRole/$userRole'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? List<Map<String, dynamic>>.from(data) : [];
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getUsersByUserRole(userRole, retry: 1);
      }
      if (response.statusCode == 403) {
        throw Exception('Permission denied');
      }

      throw Exception('Failed to load users by role: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // DEBUG USER INFO (keep only if you really need it in dev)
  // ============================================================================
  Future<void> debugUserRole() async {
    final email = await _authService.getUserEmail();
    final roles = await _authService.getUserRoles();
    final userId = await _authService.getUserId();
  }
}