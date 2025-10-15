import 'dart:convert';
import 'package:http/http.dart' as http;

class CompanyService {

  static const String baseUrl = 'http://localhost:8080';

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

  Future<Map<String, dynamic>?> getCompanyById(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/companies/$id'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load company: ${response.statusCode}');
    }
  }
  Future<Map<String, dynamic>?> getCompanyByUserID(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/companies/user/$userId'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load company: ${response.statusCode}');
    }
  }
  Future<List<Map<String, dynamic>>> getCompanyProducts(String companyId) async {
    final response = await http.get(Uri.parse('$baseUrl/companies/$companyId/products'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      } else {
        return [Map<String, dynamic>.from(decoded)];
      }
    } else {
      throw Exception('Failed to load company products: ${response.statusCode}');
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
}