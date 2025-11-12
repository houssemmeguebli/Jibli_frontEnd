import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class ProductService {
  static const String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getAllProducts({int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getAllProducts(retry: 1);
      }
      throw Exception('Failed to load products: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProductById(int id, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getProductById(id, retry: 1);
      }
      throw Exception('Failed to load product: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getProductByUserId(int userId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/user/$userId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map<Map<String, dynamic>>((product) {
          final map = Map<String, dynamic>.from(product);
          if (map['attachments'] != null && map['attachments'] is List) {
            map['attachments'] = (map['attachments'] as List)
                .map<Map<String, dynamic>>((att) => Map<String, dynamic>.from(att))
                .toList();
          } else {
            map['attachments'] = <Map<String, dynamic>>[];
          }
          return map;
        }).toList();
      }
      if (response.statusCode == 404) return [];
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getProductByUserId(userId, retry: 1);
      }
      throw Exception('Failed to load products: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> product, {int retry = 0}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/products'),
        headers: await _getHeaders(),
        body: jsonEncode(product),
      );
      if (response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return createProduct(product, retry: 1);
      }
      throw Exception('Failed to create product: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> updateProduct(int id, Map<String, dynamic> product, {int retry = 0}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/products/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(product),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return updateProduct(id, product, retry: 1);
      }
      throw Exception('Failed to update product: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteProduct(int id, {int retry = 0}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/products/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 204) return true;
      if (response.statusCode == 404) return false;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return deleteProduct(id, retry: 1);
      }
      throw Exception('Failed to delete product: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>> addAttachment(int productId, String filePath, {int retry = 0}) async {
    try {
      final token = await _authService.getAccessToken();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/products/$productId/attachments'));
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
        return addAttachment(productId, filePath, retry: 1);
      }
      throw Exception('Failed to add attachment: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getProductAttachments(int productId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/$productId/attachments'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getProductAttachments(productId, retry: 1);
      }
      throw Exception('Failed to load attachments: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getProductReviews(int productId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/$productId/reviews'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getProductReviews(productId, retry: 1);
      }
      throw Exception('Failed to load reviews: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getProductByCompanyId(int companyId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/companyProducts/$companyId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getProductByCompanyId(companyId, retry: 1);
      }
      throw Exception('Failed to load products: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getProductOrderItems(int productId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/$productId/order-items'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getProductOrderItems(productId, retry: 1);
      }
      throw Exception('Failed to load order items: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getProductByCategoryId(int categoryId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/categoryProducts/$categoryId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getProductByCategoryId(categoryId, retry: 1);
      }
      throw Exception('Failed to load products: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }
}