import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class FCMTokenService {
  static const String _baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> saveFCMToken(int userId, String fcmToken, {int retry = 0}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/save-fcm-token'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'fcmToken': fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token saved successfully for user $userId');
        return true;
      }
      if (response.statusCode == 401 && retry == 0) {
        await _authService.refreshAccessToken();
        return saveFCMToken(userId, fcmToken, retry: 1);
      }
      debugPrint('Failed to save FCM token: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
      return false;
    }
  }

  static Future<bool> updateFCMToken(int userId, String newFcmToken) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'fcmToken': newFcmToken,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token updated successfully for user $userId');
        return true;
      } else {
        debugPrint('Failed to update FCM token: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
      return false;
    }
  }

  static Future<bool> deleteFCMToken(int userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/users/$userId/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token deleted successfully for user $userId');
        return true;
      } else {
        debugPrint('Failed to delete FCM token: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
      return false;
    }
  }
}