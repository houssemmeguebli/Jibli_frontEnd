import 'dart:convert';
import 'package:http/http.dart' as http;

class OrderService {

  static const String baseUrl = 'http://localhost:8080';

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    final response = await http.get(Uri.parse('$baseUrl/orders'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      } else {
        return [Map<String, dynamic>.from(decoded)];
      }
    } else {
      throw Exception('Failed to load orders: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getOrdersByUserId(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/orders/user/$id'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map<Map<String, dynamic>>((item) => _flattenOrder(item)).toList();
      } else {
        return [_flattenOrder(decoded)];
      }
    } else {
      throw Exception('Failed to load orders: ${response.statusCode}');
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



  Future<List<Map<String, dynamic>>> getOrderById(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/orders/$userId'));
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      // Convert to List<Map<String, dynamic>>
      return jsonData.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load orders: ${response.statusCode}");
    }
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> order) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(order),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create order: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> updateOrder(int id, Map<String, dynamic> order) async {
    final response = await http.put(
      Uri.parse('$baseUrl/orders/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(order),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to update order: ${response.statusCode}');
    }
  }

  Future<bool> deleteOrder(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/orders/$id'));
    if (response.statusCode == 204) {
      return true;
    } else if (response.statusCode == 404) {
      return false;
    } else {
      throw Exception('Failed to delete order: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getOrderItems(int orderId) async {
    final response = await http.get(Uri.parse('$baseUrl/orders/$orderId/order-items'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load order items: ${response.statusCode}');
    }
  }
}