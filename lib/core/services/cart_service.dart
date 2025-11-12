import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class CartService {
  static const String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getAllCarts({int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/carts'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getAllCarts(retry: 1);
      }
      throw Exception('Failed to load carts: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> getCartById(int id, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/carts/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getCartById(id, retry: 1);
      }
      throw Exception('Failed to load cart: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> getCartByUserId(int userId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/carts/user/$userId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getCartByUserId(userId, retry: 1);
      }
      throw Exception('Failed to load cart: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCart(Map<String, dynamic> cart, {int retry = 0}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/carts'),
        headers: await _getHeaders(),
        body: jsonEncode(cart),
      );
      if (response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return createCart(cart, retry: 1);
      }
      throw Exception('Failed to create cart: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> updateCart(int id, Map<String, dynamic> cart, {int retry = 0}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/carts/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(cart),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return updateCart(id, cart, retry: 1);
      }
      throw Exception('Failed to update cart: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<bool> deleteCart(int id, {int retry = 0}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/carts/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 204) return true;
      if (response.statusCode == 404) return false;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return deleteCart(id, retry: 1);
      }
      throw Exception('Failed to delete cart: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserCartsGroupedByCompany(int userId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/carts/user/$userId/grouped'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Check if response is HTML instead of JSON
        if (response.body.trim().startsWith('<')) {
          return []; // Return empty list for missing endpoints
        }
        try {
          final List<dynamic> data = jsonDecode(response.body);
          return List<Map<String, dynamic>>.from(data);
        } catch (e) {
          return []; // Return empty list for invalid JSON
        }
      }
      if (response.statusCode == 404) return [];
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getUserCartsGroupedByCompany(userId, retry: 1);
      }
      return []; // Return empty list for other errors
    } catch (e) {
      return []; // Return empty list instead of throwing
    }
  }
}