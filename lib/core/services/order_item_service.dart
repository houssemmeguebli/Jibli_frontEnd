import 'dart:convert';
import 'package:http/http.dart' as http;

class OrderItemService {

  static const String baseUrl = 'http://192.168.1.216:8080';

  Future<List<Map<String, dynamic>>> getAllOrderItems() async {
    final response = await http.get(Uri.parse('$baseUrl/order-items'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load order items: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> getOrderItemById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/order-items/$id'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load order item: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> createOrderItem(Map<String, dynamic> orderItem) async {
    final response = await http.post(
      Uri.parse('$baseUrl/order-items'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(orderItem),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create order item: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> updateOrderItem(int id, Map<String, dynamic> orderItem) async {
    final response = await http.put(
      Uri.parse('$baseUrl/order-items/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(orderItem),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to update order item: ${response.statusCode}');
    }
  }

  Future<bool> deleteOrderItem(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/order-items/$id'));
    if (response.statusCode == 204) {
      return true;
    } else if (response.statusCode == 404) {
      return false;
    } else {
      throw Exception('Failed to delete order item: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getOrderItemsByOrder(int orderId) async {
    final response = await http.get(Uri.parse('$baseUrl/order-items/order/$orderId'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load order items for order: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getOrderItemsByProduct(int productId) async {
    final response = await http.get(Uri.parse('$baseUrl/order-items/product/$productId'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load order items for product: ${response.statusCode}');
    }
  }
}