import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class AdminBroadcastService {
  static const String baseUrl = ApiConstants.baseUrl;
  static const String endpoint = '/api/admin/broadcast';
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Send immediate broadcast to users
  Future<Map<String, dynamic>> sendBroadcast({
    required String title,
    required String body,
    required String type,
    required String targetAudience,
    int retry = 0,
  }) async {
    try {
      if (title.isEmpty) {
        throw Exception('Title is required');
      }
      if (body.isEmpty) {
        throw Exception('Body is required');
      }

      final dto = {
        'title': title,
        'body': body,
        'type': type.isNotEmpty ? type : 'ANNOUNCEMENT',
        'targetAudience': targetAudience.isNotEmpty ? targetAudience : 'ALL',
      };

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint/send'),
        headers: await _getHeaders(),
        body: jsonEncode(dto),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          return responseData['data'] ?? {};
        } else {
          throw Exception(
              responseData['message'] ?? 'Failed to send broadcast');
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return sendBroadcast(
          title: title,
          body: body,
          type: type,
          targetAudience: targetAudience,
          retry: 1,
        );
      }
      throw Exception(
          'Failed to send broadcast. Status: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  /// Schedule broadcast for later
  Future<Map<String, dynamic>> scheduleBroadcast({
    required String title,
    required String body,
    required String type,
    required String targetAudience,
    required DateTime scheduledAt,
    String? imageUrl,
    DateTime? expiresAt,
    int retry = 0,
  }) async {
    try {
      if (title.isEmpty) {
        throw Exception('Title is required');
      }
      if (body.isEmpty) {
        throw Exception('Body is required');
      }
      if (scheduledAt.isBefore(DateTime.now())) {
        throw Exception('Scheduled time must be in the future');
      }

      final dto = {
        'title': title,
        'body': body,
        'type': type.isNotEmpty ? type : 'ANNOUNCEMENT',
        'targetAudience': targetAudience.isNotEmpty ? targetAudience : 'ALL',
        'scheduledAt': scheduledAt.toIso8601String(),
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint/schedule'),
        headers: await _getHeaders(),
        body: jsonEncode(dto),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          return responseData['data'] ?? {};
        } else {
          throw Exception(
              responseData['message'] ?? 'Failed to schedule broadcast');
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return scheduleBroadcast(
          title: title,
          body: body,
          type: type,
          targetAudience: targetAudience,
          scheduledAt: scheduledAt,
          imageUrl: imageUrl,
          expiresAt: expiresAt,
          retry: 1,
        );
      }
      throw Exception(
          'Failed to schedule broadcast. Status: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  /// Get all broadcasts
  Future<List<Map<String, dynamic>>> getAllBroadcasts({int retry = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint/all'),
        headers: await _getHeaders(),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final List<dynamic> broadcasts = responseData['data'] ?? [];
          return broadcasts
              .map((item) => item as Map<String, dynamic>)
              .toList();
        } else {
          throw Exception(
              responseData['message'] ?? 'Failed to load broadcasts');
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getAllBroadcasts(retry: 1);
      }
      throw Exception(
          'Failed to load broadcasts. Status: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  /// Get broadcasts by status
  Future<List<Map<String, dynamic>>> getBroadcastsByStatus(
      String status, {
        int retry = 0,
      }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint/status/$status'),
        headers: await _getHeaders(),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final List<dynamic> broadcasts = responseData['data'] ?? [];
          return broadcasts
              .map((item) => item as Map<String, dynamic>)
              .toList();
        } else {
          throw Exception(
              responseData['message'] ?? 'Failed to load broadcasts');
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return getBroadcastsByStatus(status, retry: 1);
      }
      throw Exception(
          'Failed to load broadcasts. Status: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  /// Deactivate broadcast
  Future<bool> deactivateBroadcast(int notificationId, {int retry = 0}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint/$notificationId'),
        headers: await _getHeaders(),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          return true;
        } else {
          throw Exception(
              responseData['message'] ?? 'Failed to deactivate broadcast');
        }
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return deactivateBroadcast(notificationId, retry: 1);
      }
      throw Exception(
          'Failed to deactivate broadcast. Status: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }
}