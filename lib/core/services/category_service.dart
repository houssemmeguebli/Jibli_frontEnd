import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class CategoryService {
  static const String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getAllCategories({int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
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
        return getAllCategories(retry: 1);
      }
      throw Exception('Failed to load categories: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> getCategoryById(int id, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getCategoryById(id, retry: 1);
      }
      throw Exception('Failed to load category: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getCategoryByUserId(int userId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories/user/$userId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      if (response.statusCode == 404) return [];
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getCategoryByUserId(userId, retry: 1);
      }
      throw Exception('Failed to load categories: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> category, {int retry = 0}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/categories'),
        headers: await _getHeaders(),
        body: jsonEncode(category),
      );
      if (response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return createCategory(category, retry: 1);
      }
      throw Exception('Failed to create category: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> updateCategory(int id, Map<String, dynamic> category, {int retry = 0}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/categories/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(category),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return updateCategory(id, category, retry: 1);
      }
      throw Exception('Failed to update category: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<bool> deleteCategory(int id, {int retry = 0}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/categories/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 204) return true;
      if (response.statusCode == 404) return false;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return deleteCategory(id, retry: 1);
      }
      throw Exception('Failed to delete category: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>> addAttachment(int categoryId, String filePath, {int retry = 0}) async {
    try {
      final token = await _authService.getAccessToken();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/categories/$categoryId/attachments'));
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(responseBody));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return addAttachment(categoryId, filePath, retry: 1);
      }
      throw Exception('Failed to add attachment: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getCategoryAttachments(int categoryId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories/$categoryId/attachments'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getCategoryAttachments(categoryId, retry: 1);
      }
      throw Exception('Failed to load attachments: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }
}