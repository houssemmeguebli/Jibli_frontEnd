import 'dart:convert';
import 'package:http/http.dart' as http;

class CartService {

  static const String baseUrl = 'http://localhost:8080';

  Future<List<Map<String, dynamic>>> getAllCarts() async {
    final response = await http.get(Uri.parse('$baseUrl/carts'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load carts: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> getCartById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/carts/$id'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load cart: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> getCartByUserId(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/carts/user/$userId'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load cart: ${response.statusCode}');
    }
  }
  Future<Map<String, dynamic>> createCart(Map<String, dynamic> cart) async {
    final response = await http.post(
      Uri.parse('$baseUrl/carts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(cart),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create cart: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> updateCart(int id, Map<String, dynamic> cart) async {
    final response = await http.put(
      Uri.parse('$baseUrl/carts/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(cart),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to update cart: ${response.statusCode}');
    }
  }

  Future<bool> deleteCart(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/carts/$id'));
    if (response.statusCode == 204) {
      return true;
    } else if (response.statusCode == 404) {
      return false;
    } else {
      throw Exception('Failed to delete cart: ${response.statusCode}');
    }
  }
}