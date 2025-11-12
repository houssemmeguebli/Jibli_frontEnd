class ApiConstants {
  static const String baseUrl = 'http://192.168.1.216:8080';
  static const String apiEndpoint = '$baseUrl/api';

  static const int currentUserId = 2;

  // API Endpoints
  static const String saveFcmTokenEndpoint = '$apiEndpoint/users/save-fcm-token';
  static const String loginEndpoint = '$apiEndpoint/auth/login';
  static const String ordersEndpoint = '$apiEndpoint/orders';
}