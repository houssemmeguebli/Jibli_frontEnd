import 'dart:convert';
import 'package:http/http.dart' as http;

class ReviewService {

  static const String baseUrl = 'http://localhost:8080';

  Future<List<Map<String, dynamic>>> getAllReviews() async {
    final response = await http.get(Uri.parse('$baseUrl/reviews'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load reviews: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> getReviewById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/reviews/$id'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load review: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> createReview(Map<String, dynamic> review) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reviews'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(review),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create review: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> updateReview(int id, Map<String, dynamic> review) async {
    final response = await http.put(
      Uri.parse('$baseUrl/reviews/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(review),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to update review: ${response.statusCode}');
    }
  }

  Future<bool> deleteReview(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/reviews/$id'));
    if (response.statusCode == 204) {
      return true;
    } else if (response.statusCode == 404) {
      return false;
    } else {
      throw Exception('Failed to delete review: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getReviewsByProduct(int productId) async {
    final response = await http.get(Uri.parse('$baseUrl/reviews/product/$productId'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load reviews for product: ${response.statusCode}');
    }
  }
}