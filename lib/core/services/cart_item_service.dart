import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class CartItemService {
  static const String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getAllCartItems({int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cart-items'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        if (response.body.trim().startsWith('<')) {
          return []; // Return empty list for HTML responses
        }
        try {
          return List<Map<String, dynamic>>.from(jsonDecode(response.body));
        } catch (e) {
          return []; // Return empty list for invalid JSON
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getAllCartItems(retry: 1);
      }
      return []; // Return empty list for other errors
    } catch (e) {
      return []; // Return empty list instead of throwing
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> getCartItemById(int id, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cart-items/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getCartItemById(id, retry: 1);
      }
      throw Exception('Failed to load cart item: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addProductToUserCart(int userId, Map<String, dynamic> cartItem, {int retry = 0}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cart-items/user/$userId'),
        headers: await _getHeaders(),
        body: jsonEncode(cartItem),
      );
      if (response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return addProductToUserCart(userId, cartItem, retry: 1);
      }
      throw Exception('Failed to add product to cart: ${response.statusCode} - ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> updateCartItem(int id, Map<String, dynamic> cartItem, {int retry = 0}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/cart-items/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(cartItem),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return updateCartItem(id, cartItem, retry: 1);
      }
      throw Exception('Failed to update cart item: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<bool> deleteCartItem(int id, {int retry = 0}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/cart-items/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 204) return true;
      if (response.statusCode == 404) return false;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return deleteCartItem(id, retry: 1);
      }
      throw Exception('Failed to delete cart item: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }
}