import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';
import 'auth_service.dart';

class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    print('🔧 Initializing Firebase Messaging Service...');

    try {
      // Request permissions
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('✅ Permissions requested');

      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      print('✅ Local notifications initialized');

      // Create notification channel
      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
      print('✅ Notification channel created');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      print('✅ Foreground listener registered');

      // Handle background messages
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      print('✅ Background listener registered');

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        print('🔄 FCM Token refreshed');
        final authService = AuthService();
        final userId = await authService.getUserId();
        if (userId != null) {
          _saveFCMToken(newToken, userId);
        }
      });

      // Get and save FCM token AUTOMATICALLY
      await _getAndSaveFCMToken();

      print('✅ Firebase Messaging initialized successfully');
    } catch (e) {
      print('❌ Firebase initialization error: $e');
    }
  }

  /// Get FCM token and save to backend automatically
  static Future<void> _getAndSaveFCMToken() async {
    try {
      final authService = AuthService();
      final userId = await authService.getUserId();
      
      if (userId == null) {
        print('❌ No user logged in, skipping FCM token save');
        return;
      }
      
      print('📱 Getting FCM token for user: $userId');

      final token = await _firebaseMessaging.getToken();

      if (token != null) {
        print('🔑 FCM Token: ${token.substring(0, 30)}...');
        await _saveFCMToken(token, userId);
      } else {
        print('❌ FCM Token is null');
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  /// Save FCM token to backend
  static Future<void> _saveFCMToken(String token, int userId) async {
    try {
      print('💾 Saving FCM token for user: $userId');
      print('   Endpoint: ${ApiConstants.saveFcmTokenEndpoint}');

      final response = await http.post(
        Uri.parse(ApiConstants.saveFcmTokenEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'fcmToken': token,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ FCM Token saved successfully');
      } else {
        print('❌ Failed to save token: ${response.statusCode}');
        print('   Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('🔔 FOREGROUND MESSAGE RECEIVED');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');
    print('   Data: ${message.data}');

    await _showLocalNotification(message);
  }

  /// Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('🔔 BACKGROUND MESSAGE RECEIVED');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');
    print('   Message ID: ${message.messageId}');

    if (message.data.containsKey('route')) {
      print('   Navigate to: ${message.data['route']}');
    }
  }

  /// Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    print('📢 SHOWING LOCAL NOTIFICATION');
    try {
      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final title = message.notification?.title ?? 'Notification';
      final body = message.notification?.body ?? 'You have a new message';

      print('📢 About to show: $title - $body');

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
      );

      print('✅ NOTIFICATION DISPLAYED');
    } catch (e) {
      print('❌ ERROR DISPLAYING NOTIFICATION: $e');
    }
  }

  /// Handle notification tap
  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      print('👆 Notification tapped with data: $data');

      if (data.containsKey('route')) {
        print('   Navigate to: ${data['route']}');
      }
    }
  }

  /// Get current FCM token
  static Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Show snackbar notification
  static void showSnackBarNotification(BuildContext context, String title, String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}