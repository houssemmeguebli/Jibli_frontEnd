import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class CompanyService {
  static const String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getAllCompanies({int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies'),
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
        return getAllCompanies(retry: 1);
      }
      throw Exception('Failed to load companies: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getActiveCompanies({int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies/activeCompany'),
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
        return getActiveCompanies(retry: 1);
      }
      throw Exception('Failed to load companies: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> getCompanyById(int id, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getCompanyById(id, retry: 1);
      }
      throw Exception('Failed to load company: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getCompanyByUserID(int userId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies/user/$userId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        } else if (decoded is Map<String, dynamic>) {
          return [Map<String, dynamic>.from(decoded)];
        }
        return [];
      }
      if (response.statusCode == 404) return [];
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getCompanyByUserID(userId, retry: 1);
      }
      throw Exception('Failed to load company: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> getCompanyProducts(int companyId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies/$companyId/products'),
        headers: await _getHeaders(),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getCompanyProducts(companyId, retry: 1);
      }
      throw Exception('Failed to load company products: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching company products: $e');
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>> findByCompanyIdWithReviews(int companyId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies/$companyId/reviews'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) {
        throw Exception('Company not found');
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return findByCompanyIdWithReviews(companyId, retry: 1);
      }
      throw Exception('Failed to fetch company reviews: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching company reviews: $e');
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>> findByCompanyIdWithCategories(int companyId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies/$companyId/categories'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 404) {
        throw Exception('Company not found');
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return findByCompanyIdWithCategories(companyId, retry: 1);
      }
      throw Exception('Failed to fetch company categories: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching company categories: $e');
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getCompaniesByCategory(String categoryId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies?category=$categoryId'),
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
        return getCompaniesByCategory(categoryId, retry: 1);
      }
      throw Exception('Failed to load companies by category: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCompany(Map<String, dynamic> company, {int retry = 0}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/companies'),
        headers: await _getHeaders(),
        body: jsonEncode(company),
      );
      if (response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return createCompany(company, retry: 1);
      }
      throw Exception('Failed to create company: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> updateCompany(int id, Map<String, dynamic> company, {int retry = 0}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/companies/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(company),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 404) {
        return null;
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return updateCompany(id, company, retry: 1);
      }
      throw Exception('Failed to update company: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<bool> deleteCompany(int id, {int retry = 0}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/companies/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 204) return true;
      if (response.statusCode == 404) return false;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return deleteCompany(id, retry: 1);
      }
      throw Exception('Failed to delete company: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getOrdersByCompanyId(int companyId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/companies/$companyId/orders'),
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
        return getOrdersByCompanyId(companyId, retry: 1);
      }
      throw Exception('Failed to load company orders: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }
}