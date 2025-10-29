import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductService {

  static const String baseUrl = 'http://192.168.1.216:8080';


  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/products'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load products: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> getProductById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/products/$id'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load product: ${response.statusCode}');
    }
  }
  Future<List<Map<String, dynamic>>> getProductByUserId(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/products/user/$userId'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      // Convert each product to Map<String, dynamic>
      return data.map<Map<String, dynamic>>((product) {
        final map = Map<String, dynamic>.from(product);

        // Ensure attachments is always a List<Map<String, dynamic>>
        if (map['attachments'] != null && map['attachments'] is List) {
          map['attachments'] = (map['attachments'] as List)
              .map<Map<String, dynamic>>(
                  (att) => Map<String, dynamic>.from(att))
              .toList();
        } else {
          map['attachments'] = <Map<String, dynamic>>[];
        }

        return map;
      }).toList();
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw Exception('Failed to load products: ${response.statusCode}');
    }
  }


  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> product) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(product),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create product: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> updateProduct(int id, Map<String, dynamic> product) async {
    final response = await http.put(
      Uri.parse('$baseUrl/products/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(product),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to update product: ${response.statusCode}');
    }
  }

  Future<bool> deleteProduct(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/products/$id'));
    if (response.statusCode == 204) {
      return true;
    } else if (response.statusCode == 404) {
      return false;
    } else {
      throw Exception('Failed to delete product: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> addAttachment(int productId, String filePath) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/products/$productId/attachments'));
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(responseBody));
    } else {
      throw Exception('Failed to add attachment: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getProductAttachments(int productId) async {
    final response = await http.get(Uri.parse('$baseUrl/products/$productId/attachments'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load attachments: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getProductReviews(int productId) async {
    final response = await http.get(Uri.parse('$baseUrl/products/$productId/reviews'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load reviews: ${response.statusCode}');
    }
  }
  Future<List<Map<String, dynamic>>> getProductByCompanyId(int companyId) async {
    final response = await http.get(Uri.parse('$baseUrl/products/companyProducts/$companyId'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load orders: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getProductOrderItems(int productId) async {
    final response = await http.get(Uri.parse('$baseUrl/products/$productId/order-items'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load order items: ${response.statusCode}');
    }
  }

}