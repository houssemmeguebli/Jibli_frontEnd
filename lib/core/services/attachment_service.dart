import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class AttachmentService {
  static const String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Helper to handle responses
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          return {'message': 'Success'};
        }
      }
      return {'message': 'Success'};
    } else {
      String errorMessage = 'Request failed with status: ${response.statusCode}';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('error')) {
          errorMessage = errorBody['error'];
        }
      } catch (e) {
        errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
      }
      throw Exception(errorMessage);
    }
  }

  Future<List<Map<String, dynamic>>> getAllAttachments({int retry = 0}) async {
    try {
      final headers = await _getHeaders();
      headers['Accept'] = 'application/json';
      final response = await http.get(
        Uri.parse('$baseUrl/attachments'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getAllAttachments(retry: 1);
      }
      throw Exception('Failed to load attachments: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<Map<String, dynamic>?> getAttachmentById(int id, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attachments/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getAttachmentById(id, retry: 1);
      }
      final error = await _handleResponse(response);
      throw Exception(error['error'] ?? 'Failed to load attachment');
    } catch (e) {
      throw Exception('Error fetching attachment: $e');
    }
  }

  // ✅ FIXED: Added token to headers
  Future<AttachmentDownload> downloadAttachment(int id, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attachments/download/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        String? filename;
        final contentDisposition = response.headers['content-disposition'];
        if (contentDisposition != null) {
          final filenameMatch = RegExp(r'filename="?([^"]+)"?')
              .firstMatch(contentDisposition);
          if (filenameMatch != null) {
            filename = filenameMatch.group(1);
          }
        }

        final contentType = response.headers['content-type'] ?? 'application/octet-stream';

        return AttachmentDownload(
          data: response.bodyBytes,
          filename: filename ?? 'download',
          contentType: contentType,
        );
      }
      if (response.statusCode == 404) {
        throw Exception('Attachment not found');
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return downloadAttachment(id, retry: 1);
      }
      throw Exception('Failed to download attachment: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error downloading attachment: $e');
    }
  }

  // ✅ FIXED: Added token to headers
  Future<Map<String, dynamic>> createAttachment({
    required Uint8List fileBytes,
    required String fileName,
    required String contentType,
    required String entityType,
    required int entityId,
    int retry = 0,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/attachments');
      final request = http.MultipartRequest('POST', uri);

      if (fileBytes.isEmpty) {
        throw Exception('File data cannot be empty');
      }

      if (fileName.trim().isEmpty) {
        throw Exception('File name is required');
      }

      if (!_isValidEntityType(entityType)) {
        throw Exception('Invalid entity type. Must be: PRODUCT, CATEGORY, USER, or COMPANY');
      }

      // Add authorization header
      final token = await _authService.getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(contentType),
      ));

      request.fields['entityType'] = entityType.toUpperCase();
      request.fields['entityId'] = entityId.toString();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return createAttachment(
          fileBytes: fileBytes,
          fileName: fileName,
          contentType: contentType,
          entityType: entityType,
          entityId: entityId,
          retry: 1,
        );
      }
      final errorData = await _handleResponse(response);
      throw Exception(errorData['error'] ?? 'Failed to create attachment');
    } catch (e) {
      throw Exception('Error creating attachment: $e');
    }
  }

  // ✅ FIXED: Added token to headers
  Future<Map<String, dynamic>> updateAttachment({
    required int id,
    Uint8List? fileBytes,
    String? fileName,
    String? contentType,
    String? entityType,
    int? entityId,
    int retry = 0,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/attachments/$id');
      final request = http.MultipartRequest('PUT', uri);

      if (fileBytes != null && fileName != null && contentType != null) {
        if (fileBytes.isEmpty) {
          throw Exception('File data cannot be empty');
        }
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ));
      }

      if (entityType != null) {
        if (!_isValidEntityType(entityType)) {
          throw Exception('Invalid entity type');
        }
        request.fields['entityType'] = entityType.toUpperCase();
      }

      if (entityId != null) {
        request.fields['entityId'] = entityId.toString();
      }

      // Add authorization header
      final token = await _authService.getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 404) {
        throw Exception('Attachment not found');
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return updateAttachment(
          id: id,
          fileBytes: fileBytes,
          fileName: fileName,
          contentType: contentType,
          entityType: entityType,
          entityId: entityId,
          retry: 1,
        );
      }
      final errorData = await _handleResponse(response);
      throw Exception(errorData['error'] ?? 'Failed to update attachment');
    } catch (e) {
      throw Exception('Error updating attachment: $e');
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> findByProductProductId(int productId, {int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attachments/product/$productId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> attachmentsList = jsonData is List ? jsonData : [];
        return attachmentsList.cast<Map<String, dynamic>>();
      }
      if (response.statusCode == 404) return [];
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return findByProductProductId(productId, retry: 1);
      }
      throw Exception('Failed to fetch attachments: ${response.statusCode}');
    } catch (e) {
      return [];
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<bool> deleteAttachment(int id, {int retry = 0}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/attachments/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 204) return true;
      if (response.statusCode == 404) return false;
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return deleteAttachment(id, retry: 1);
      }
      final errorData = await _handleResponse(response);
      throw Exception(errorData['error'] ?? 'Failed to delete attachment');
    } catch (e) {
      throw Exception('Error deleting attachment: $e');
    }
  }

  // ✅ FIXED: Added headers and token refresh logic
  Future<List<Map<String, dynamic>>> getAttachmentsByEntity(
      String entityType,
      int entityId, {
        int retry = 0,
      }) async {
    try {
      if (!_isValidEntityType(entityType)) {
        throw Exception('Invalid entity type. Must be: PRODUCT, CATEGORY, USER, or COMPANY');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/attachments/entity/${entityType.toUpperCase()}/$entityId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      }
      if (response.statusCode == 400) {
        final errorData = await _handleResponse(response);
        throw Exception(errorData['error'] ?? 'Invalid request parameters');
      }
      if (response.statusCode == 404) return [];
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getAttachmentsByEntity(entityType, entityId, retry: 1);
      }
      throw Exception('Failed to load attachments: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching attachments by entity: $e');
    }
  }

  bool _isValidEntityType(String entityType) {
    final validTypes = ['PRODUCT', 'CATEGORY', 'USER', 'COMPANY'];
    return validTypes.contains(entityType.toUpperCase());
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  bool isFileTypeAllowed(String contentType) {
    final allowedTypes = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'application/pdf',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ];
    return allowedTypes.contains(contentType.toLowerCase());
  }

  int get maxFileSize => 10 * 1024 * 1024;
}

class AttachmentDownload {
  final Uint8List data;
  final String filename;
  final String contentType;

  AttachmentDownload({
    required this.data,
    required this.filename,
    required this.contentType,
  });

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf';
  bool get isExcel => contentType.contains('excel') || contentType.contains('spreadsheet');
}