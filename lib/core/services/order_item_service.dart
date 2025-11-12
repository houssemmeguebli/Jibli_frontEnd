import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class OrderItemService {
  static const String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getAllOrderItems({int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/order-items'),
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
        return getAllOrderItems(retry: 1);
      }
      return []; // Return empty list for other errors
    } catch (e) {
      return []; // Return empty list instead of throwing
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> getOrderItemById(int id, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/order-items/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getOrderItemById(id, retry: 1);
      }
      throw Exception('Failed to load order item: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOrderItem(Map<String, dynamic> orderItem, {int retry = 0}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/order-items'),
        headers: await _getHeaders(),
        body: jsonEncode(orderItem),
      );
      if (response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return createOrderItem(orderItem, retry: 1);
      }
      throw Exception('Failed to create order item: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> updateOrderItem(int id, Map<String, dynamic> orderItem, {int retry = 0}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/order-items/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(orderItem),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return updateOrderItem(id, orderItem, retry: 1);
      }
      throw Exception('Failed to update order item: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<bool> deleteOrderItem(int id, {int retry = 0}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/order-items/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 204) return true;
      if (response.statusCode == 404) return false;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return deleteOrderItem(id, retry: 1);
      }
      throw Exception('Failed to delete order item: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getOrderItemsByOrder(int orderId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/order-items/order/$orderId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        if (response.body.trim().startsWith('<')) {
          return [];
        }
        try {
          return List<Map<String, dynamic>>.from(jsonDecode(response.body));
        } catch (e) {
          return [];
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getOrderItemsByOrder(orderId, retry: 1);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getOrderItemsByProduct(int productId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/order-items/product/$productId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        if (response.body.trim().startsWith('<')) {
          return [];
        }
        try {
          return List<Map<String, dynamic>>.from(jsonDecode(response.body));
        } catch (e) {
          return [];
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getOrderItemsByProduct(productId, retry: 1);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}