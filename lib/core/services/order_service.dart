import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class OrderService {
  static const String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getAllOrders({int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders'),
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
        return getAllOrders(retry: 1);
      }
      throw Exception('Failed to load orders: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getOrdersByUserId(int id, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/user/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map<Map<String, dynamic>>((item) => _flattenOrder(item)).toList();
        } else {
          return [_flattenOrder(decoded)];
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getOrdersByUserId(id, retry: 1);
      }
      throw Exception('Failed to load orders: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> _flattenOrder(dynamic orderData) {
    final Map<String, dynamic> flattened = {};

    if (orderData is Map<String, dynamic>) {
      orderData.forEach((key, value) {
        if (value is List) {
          flattened[key] = value.join(', ');
        } else if (value is Map) {
          flattened[key] = value.toString();
        } else {
          flattened[key] = value;
        }
      });
    }

    return flattened;
  }

  Future<void> patchOrderStatus(int id, String orderStatus, {int retry = 0}) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/orders/orderStatus/$id'),
        headers: await _getHeaders(),
        body: jsonEncode({'orderStatus': orderStatus}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) return;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return patchOrderStatus(id, orderStatus, retry: 1);
      }
      throw Exception('Failed to update order status: ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getOrderById(int userId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/$userId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.cast<Map<String, dynamic>>();
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getOrderById(userId, retry: 1);
      }
      throw Exception("Failed to load orders: ${response.statusCode}");
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> order, {int retry = 0}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: await _getHeaders(),
        body: jsonEncode(order),
      );
      if (response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return createOrder(order, retry: 1);
      }
      throw Exception('Failed to create order: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> updateOrder(int id, Map<String, dynamic> order, {int retry = 0}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(order),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) {
        return null;
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return updateOrder(id, order, retry: 1);
      }
      throw Exception('Failed to update order: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<bool> deleteOrder(int id, {int retry = 0}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/orders/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      }
      if (response.statusCode == 404) {
        return false;
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return deleteOrder(id, retry: 1);
      }
      throw Exception('Failed to delete order: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getOrderItems(int orderId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/$orderId/order-items'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getOrderItems(orderId, retry: 1);
      }
      throw Exception('Failed to load order items: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getOrdersByDeliveryId(int deliveryId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/deliveryOrders/$deliveryId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map<Map<String, dynamic>>((item) => _flattenOrder(item)).toList();
        } else {
          return [_flattenOrder(decoded)];
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getOrdersByDeliveryId(deliveryId, retry: 1);
      }
      throw Exception('Failed to load orders: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getOrdersByCompanyId(int companyId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/companyOrders/$companyId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map<Map<String, dynamic>>((item) => _flattenOrder(item)).toList();
        } else {
          return [_flattenOrder(decoded)];
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getOrdersByCompanyId(companyId, retry: 1);
      }
      throw Exception('Failed to load orders: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }
  Future<List<Map<String, dynamic>>> getOrdersByCompanyUserId(int userId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/companyOrders/user/$userId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map<Map<String, dynamic>>((item) => _flattenOrder(item)).toList();
        } else {
          return [_flattenOrder(decoded)];
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getOrdersByCompanyUserId(userId, retry: 1);
      }
      throw Exception('Failed to load orders: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

}