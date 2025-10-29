import 'dart:convert';
import 'package:http/http.dart' as http;

class CompanyService {

  static const String baseUrl = 'http://192.168.1.216:8080';

  Future<List<Map<String, dynamic>>> getAllCompanies() async {
    final response = await http.get(Uri.parse('$baseUrl/companies'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      } else {
        return [Map<String, dynamic>.from(decoded)];
      }
    } else {
      throw Exception('Failed to load companies: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> getCompanyById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/companies/$id'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load company: ${response.statusCode}');
    }
  }
  Future<List<Map<String, dynamic>>> getCompanyByUserID(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/companies/user/$userId'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // If response is a List, convert each item to Map
      if (decoded is List) {
        return decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      // If response is a Map, wrap it in a List
      else if (decoded is Map<String, dynamic>) {
        return [Map<String, dynamic>.from(decoded)];
      }
      return [];
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw Exception('Failed to load company: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> getCompanyProducts(int companyId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies/$companyId/products'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load company products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching company products: $e');
    }
  }
  // Get company with reviews
  Future<Map<String, dynamic>> findByCompanyIdWithReviews(int companyId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies/$companyId/reviews'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        throw Exception('Company not found');
      } else {
        throw Exception('Failed to fetch company reviews: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching company reviews: $e');
    }
  }

  // Get company with categories
  Future<Map<String, dynamic>> findByCompanyIdWithCategories(int companyId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies/$companyId/categories'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        throw Exception('Company not found');
      } else {
        throw Exception('Failed to fetch company categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching company categories: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCompaniesByCategory(String categoryId) async {
    final response = await http.get(Uri.parse('$baseUrl/companies?category=$categoryId'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      } else {
        return [Map<String, dynamic>.from(decoded)];
      }
    } else {
      throw Exception('Failed to load companies by category: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> createCompany(Map<String, dynamic> company) async {
    final response = await http.post(
      Uri.parse('$baseUrl/companies'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(company),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create company: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> updateCompany(int id, Map<String, dynamic> company) async {
    final response = await http.put(
      Uri.parse('$baseUrl/companies/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(company),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to update company: ${response.statusCode}');
    }
  }

  Future<bool> deleteCompany(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/companies/$id'));
    if (response.statusCode == 204) {
      return true;
    } else if (response.statusCode == 404) {
      return false;
    } else {
      throw Exception('Failed to delete company: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getOrdersByCompanyId(int companyId) async {
    final response = await http.get(Uri.parse('$baseUrl/companies/$companyId/orders'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      } else {
        return [Map<String, dynamic>.from(decoded)];
      }
    } else {
      throw Exception('Failed to load company orders: ${response.statusCode}');
    }
  }

}