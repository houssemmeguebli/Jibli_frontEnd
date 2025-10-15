import 'dart:convert';
import 'package:http/http.dart' as http;

class CategoryService {

  static const String baseUrl = 'http://localhost:8080';

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/categories'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      } else {
        return [Map<String, dynamic>.from(decoded)];
      }
    } else {
      throw Exception('Failed to load categories: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> getCategoryById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/categories/$id'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load category: ${response.statusCode}');
    }
  }
  Future<List<Map<String, dynamic>>> getCategoryByUserId(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/categories/user/$userId'));

    if (response.statusCode == 200) {
      // Decode response body as a List of Maps
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    } else if (response.statusCode == 404) {
      // Return empty list if not found
      return [];
    } else {
      throw Exception('Failed to load categories: ${response.statusCode}');
    }
  }


  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> category) async {
    final response = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(category),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create category: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> updateCategory(int id, Map<String, dynamic> category) async {
    final response = await http.put(
      Uri.parse('$baseUrl/categories/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(category),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to update category: ${response.statusCode}');
    }
  }

  Future<bool> deleteCategory(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/categories/$id'));
    if (response.statusCode == 204) {
      return true;
    } else if (response.statusCode == 404) {
      return false;
    } else {
      throw Exception('Failed to delete category: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> addAttachment(int categoryId, String filePath) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/categories/$categoryId/attachments'));
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(responseBody));
    } else {
      throw Exception('Failed to add attachment: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getCategoryAttachments(int categoryId) async {
    final response = await http.get(Uri.parse('$baseUrl/categories/$categoryId/attachments'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load attachments: ${response.statusCode}');
    }
  }
}