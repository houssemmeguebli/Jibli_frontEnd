import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class AttachmentService {
  static const String baseUrl = 'http://192.168.1.216:8080';

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

  // GET /attachments - Get all attachments (returns metadata only, no file data)
  Future<List<Map<String, dynamic>>> getAllAttachments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attachments'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load attachments: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching attachments: $e');
    }
  }

  // GET /attachments/{id} - Get attachment metadata by ID
  Future<Map<String, dynamic>?> getAttachmentById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attachments/$id'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        final error = await _handleResponse(response);
        throw Exception(error['error'] ?? 'Failed to load attachment');
      }
    } catch (e) {
      throw Exception('Error fetching attachment: $e');
    }
  }

  // GET /attachments/download/{id} - Download attachment file data
  Future<AttachmentDownload> downloadAttachment(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attachments/download/$id'),
      );

      if (response.statusCode == 200) {
        // Extract filename from Content-Disposition header
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
      } else if (response.statusCode == 404) {
        throw Exception('Attachment not found');
      } else {
        throw Exception('Failed to download attachment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error downloading attachment: $e');
    }
  }

  // POST /attachments - Create attachment (multipart with file, entityType, entityId)
  Future<Map<String, dynamic>> createAttachment({
    required Uint8List fileBytes,
    required String fileName,
    required String contentType, // e.g., 'image/jpeg', 'application/pdf'
    required String entityType, // 'PRODUCT', 'CATEGORY', 'USER', 'COMPANY'
    required int entityId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/attachments');
      final request = http.MultipartRequest('POST', uri);

      // Validate inputs before sending
      if (fileBytes.isEmpty) {
        throw Exception('File data cannot be empty');
      }

      if (fileName.trim().isEmpty) {
        throw Exception('File name is required');
      }

      if (!_isValidEntityType(entityType)) {
        throw Exception('Invalid entity type. Must be: PRODUCT, CATEGORY, USER, or COMPANY');
      }

      // Add the file part
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(contentType),
      ));

      // Add form fields (entityType will be normalized to uppercase in backend)
      request.fields['entityType'] = entityType.toUpperCase();
      request.fields['entityId'] = entityId.toString();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorData = await _handleResponse(response);
        throw Exception(errorData['error'] ?? 'Failed to create attachment');
      }
    } catch (e) {
      throw Exception('Error creating attachment: $e');
    }
  }

  // PUT /attachments/{id} - Update attachment
  Future<Map<String, dynamic>> updateAttachment({
    required int id,
    Uint8List? fileBytes,
    String? fileName,
    String? contentType,
    String? entityType,
    int? entityId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/attachments/$id');
      final request = http.MultipartRequest('PUT', uri);

      // Add file if provided
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

      // Add entity fields if provided
      if (entityType != null) {
        if (!_isValidEntityType(entityType)) {
          throw Exception('Invalid entity type');
        }
        request.fields['entityType'] = entityType.toUpperCase();
      }

      if (entityId != null) {
        request.fields['entityId'] = entityId.toString();
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw Exception('Attachment not found');
      } else {
        final errorData = await _handleResponse(response);
        throw Exception(errorData['error'] ?? 'Failed to update attachment');
      }
    } catch (e) {
      throw Exception('Error updating attachment: $e');
    }
  }
  // Get attachments by product ID
  Future<List<Map<String, dynamic>>> findByProductProductId(int productId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attachments/product/$productId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> attachmentsList = jsonData is List ? jsonData : [];
        return attachmentsList.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 404) {
        debugPrint('No attachments found for product $productId');
        return [];
      } else {
        throw Exception('Failed to fetch attachments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching attachments for product $productId: $e');
      return [];
    }
  }

  // DELETE /attachments/{id} - Delete attachment
  Future<bool> deleteAttachment(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/attachments/$id'),
      );

      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 404) {
        return false;
      } else {
        final errorData = await _handleResponse(response);
        throw Exception(errorData['error'] ?? 'Failed to delete attachment');
      }
    } catch (e) {
      throw Exception('Error deleting attachment: $e');
    }
  }

  // GET /attachments/entity/{entityType}/{entityId} - Get attachments by entity
  Future<List<Map<String, dynamic>>> getAttachmentsByEntity(
      String entityType,
      int entityId
      ) async {
    try {
      if (!_isValidEntityType(entityType)) {
        throw Exception('Invalid entity type. Must be: PRODUCT, CATEGORY, USER, or COMPANY');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/attachments/entity/${entityType.toUpperCase()}/$entityId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 400) {
        final errorData = await _handleResponse(response);
        throw Exception(errorData['error'] ?? 'Invalid request parameters');
      } else if (response.statusCode == 404) {
        return []; // Entity exists but has no attachments
      } else {
        throw Exception('Failed to load attachments: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching attachments by entity: $e');
    }
  }

  // Helper method to validate entity types
  bool _isValidEntityType(String entityType) {
    final validTypes = ['PRODUCT', 'CATEGORY', 'USER', 'COMPANY'];
    return validTypes.contains(entityType.toUpperCase());
  }

  // Helper to get file size in human-readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Helper to check if file type is allowed
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

  // Helper to get max file size (10MB)
  int get maxFileSize => 10 * 1024 * 1024;
}

// Data class for download response
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