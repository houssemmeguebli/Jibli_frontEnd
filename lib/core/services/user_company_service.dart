import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class UserCompanyService {
  static const String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getAllUserCompanies({int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user-companies'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        } else {
          return [Map<String, dynamic>.from(decoded)];
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getAllUserCompanies(retry: 1);
      }
      throw Exception('Failed to load user companies: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserCompanyById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/user-companies/$id'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load user company: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> createUserCompany(Map<String, dynamic> userCompany, {int retry = 0}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user-companies'),
        headers: await _getHeaders(),
        body: jsonEncode(userCompany),
      );
      if (response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return createUserCompany(userCompany, retry: 1);
      }
      throw Exception('Failed to create user company: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> updateUserCompany(int id, Map<String, dynamic> userCompany) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user-companies/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userCompany),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to update user company: ${response.statusCode}');
    }
  }

  Future<bool> deleteUserCompany(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/user-companies/$id'));
    if (response.statusCode == 204) {
      return true;
    } else if (response.statusCode == 404) {
      return false;
    } else {
      throw Exception('Failed to delete user company: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getUserCompaniesByUser(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/user-companies/user/$userId'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      } else {
        return [Map<String, dynamic>.from(decoded)];
      }
    } else {
      throw Exception('Failed to load user companies for user: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getUserCompaniesByCompany(int companyId) async {
    final response = await http.get(Uri.parse('$baseUrl/user-companies/company/$companyId'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      } else {
        return [Map<String, dynamic>.from(decoded)];
      }
    } else {
      throw Exception('Failed to load user companies for company: ${response.statusCode}');
    }
  }
}