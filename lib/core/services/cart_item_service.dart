import 'dart:convert';
import 'package:http/http.dart' as http;

class CartItemService {
  final String baseUrl;

  CartItemService(this.baseUrl);

  /// Fetches all cart items
  Future<List<Map<String, dynamic>>> getAllCartItems() async {
    final response = await http.get(Uri.parse('$baseUrl/cart-items'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load cart items: ${response.statusCode}');
    }
  }

  /// Fetches a cart item by its ID
  Future<Map<String, dynamic>?> getCartItemById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/cart-items/$id'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load cart item: ${response.statusCode}');
    }
  }

  /// Creates a new cart item
  Future<Map<String, dynamic>> createCartItem(Map<String, dynamic> cartItem) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cart-items'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(cartItem),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create cart item: ${response.statusCode}');
    }
  }

  /// Updates an existing cart item
  Future<Map<String, dynamic>?> updateCartItem(int id, Map<String, dynamic> cartItem) async {
    final response = await http.put(
      Uri.parse('$baseUrl/cart-items/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(cartItem),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to update cart item: ${response.statusCode}');
    }
  }

  /// Deletes a cart item
  Future<bool> deleteCartItem(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/cart-items/$id'));
    if (response.statusCode == 204) {
      return true;
    } else if (response.statusCode == 404) {
      return false;
    } else {
      throw Exception('Failed to delete cart item: ${response.statusCode}');
    }
  }
}