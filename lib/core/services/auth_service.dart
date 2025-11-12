import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class AuthService {
  static const String baseUrl = ApiConstants.baseUrl;
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userEmailKey = 'user_email';
  static const String _userPhoneKey = 'user_phone';
  static const String _userRolesKey = 'user_roles';
  static const String _userIdKey = 'user_id';
  static const String _userName = 'user_fullName';

  static const _storage = FlutterSecureStorage();

  // ✅ Login - Get access token and refresh token (Email or Phone)
  Future<Map<String, dynamic>?> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      // Validate that either email or phone is provided
      if ((email == null || email.isEmpty) && (phone == null || phone.isEmpty)) {
        throw Exception('Please provide either email or phone');
      }

      if (password.isEmpty) {
        throw Exception('Password is required');
      }

      print('🔐 Attempting login to: $baseUrl/api/auth/login');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (email != null && email.isNotEmpty) 'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          'password': password,
        }),
      ).timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Login request timeout');
      });

      print('📡 Login response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));

        // ✅ Extract refresh token data properly
        final refreshTokenData = data['refreshToken'];
        String refreshTokenValue = '';

        if (refreshTokenData is String) {
          refreshTokenValue = refreshTokenData;
        } else if (refreshTokenData is Map) {
          refreshTokenValue = refreshTokenData['token'] ?? '';
        }

        if (refreshTokenValue.isEmpty) {
          throw Exception('No refresh token received from server');
        }

        // ✅ Save tokens and user info locally
        await _saveTokens(
          accessToken: data['accessToken'] ?? '',
          refreshToken: refreshTokenValue,
          email: data['email'] ?? '',
          phone: data['phone'],
          roles: data['roles'] ?? [],
          userId: data['userId'] ?? 0,
          fullName: data['fullName'] ?? '',
        );

        print('✅ Login successful for user: ${data['email']}');
        return data;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Validation failed');
      } else if (response.statusCode == 401) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Invalid email/phone or password');
      } else if (response.statusCode == 403) {
        // ✅ 403 FORBIDDEN - Account is inactive or banned
        final errorData = jsonDecode(response.body);
        final error = errorData['error'] ?? 'Account error';
        final message = errorData['message'] ?? '';

        // Throw exception with the exact error from backend
        throw Exception('$error: $message');
      } else {
        throw Exception('Login failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  // ✅ Register - Create new user account
  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String fullName,
    String? address,
    String? phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'fullName': fullName,
          'address': address ?? '',
          'phone': phone ?? '',
        }),
      ).timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Registration request timeout');
      });

      print('📡 Register response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        print('✅ Registration successful');
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else if (response.statusCode == 409) {
        throw Exception('Email already exists');
      } else {
        throw Exception('Registration failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Registration error: $e');
      throw Exception('Registration error: $e');
    }
  }
  Future<Map<String, dynamic>?> registerAdmin({
    required String email,
    required String password,
    required String fullName,
    String? address,
    String? phone,
    String? roles,
  }) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/adminRegister'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'fullName': fullName,
          'address': address ?? '',
          'phone': phone ?? '',
          'roles': roles ?? '',
        }),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Admin registration request timeout');
      });

      print('📡 Admin register response status: ${response.statusCode}');
      print('📦 Admin register response body: ${response.body}');

      if (response.statusCode == 201) {
        print('✅ Admin registration successful');
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else if (response.statusCode == 409) {
        throw Exception('Email already exists');
      } else if (response.statusCode == 403) {
        throw Exception('Not authorized to register admin');
      } else {
        throw Exception(
            'Admin registration failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Admin registration error: $e');
      throw Exception('Admin registration error: $e');
    }
  }
  // ✅ Step 1: Request password reset PIN
  Future<Map<String, dynamic>?> forgotPassword({
    required String email,
  }) async {
    try {
      if (email.isEmpty) {
        throw Exception('Email is required');
      }

      print('🔐 Requesting password reset PIN for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
        }),
      ).timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Forgot password request timeout');
      });

      print('📡 Forgot password response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
        print('✅ PIN sent successfully to: $email');
        return data;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Validation failed');
      } else {
        throw Exception(
            'Forgot password failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Forgot password error: $e');
      throw Exception('Forgot password error: $e');
    }
  }

  // ✅ Step 2: Verify PIN code
  Future<Map<String, dynamic>?> verifyPin({
    required String email,
    required String pin,
  }) async {
    try {
      if (email.isEmpty) {
        throw Exception('Email is required');
      }

      if (pin.isEmpty) {
        throw Exception('PIN code is required');
      }

      print('🔍 Verifying PIN code for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/verify-pin'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'pin': pin,
        }),
      ).timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Verify PIN request timeout');
      });

      print('📡 Verify PIN response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
        print('✅ PIN verified successfully');
        return data;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Validation failed');
      } else if (response.statusCode == 401) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Invalid PIN code or email');
      } else if (response.statusCode == 403) {
        throw Exception('Too many failed attempts. Please request a new PIN code');
      } else {
        throw Exception('PIN verification failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Verify PIN error: $e');
      throw Exception('Verify PIN error: $e');
    }
  }

  // ✅ Step 3: Reset password after PIN verification
  Future<Map<String, dynamic>?> resetPassword({
    required String email,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      if (email.isEmpty) {
        throw Exception('Email is required');
      }

      if (newPassword.isEmpty) {
        throw Exception('New password is required');
      }

      if (newPassword.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      if (newPassword != confirmPassword) {
        throw Exception('Passwords do not match');
      }

      print('🔐 Resetting password for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        }),
      ).timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Reset password request timeout');
      });

      print('📡 Reset password response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
        print('✅ Password reset successfully');
        return data;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Validation failed');
      } else if (response.statusCode == 401) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'PIN verification required');
      } else {
        throw Exception('Password reset failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Reset password error: $e');
      throw Exception('Reset password error: $e');
    }
  }


  // ✅ Refresh Access Token - Get new token using refresh token
  Future<Map<String, dynamic>?> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('No refresh token available');
      }

      print('🔄 Refreshing access token...');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'refreshToken': refreshToken,
        }),
      ).timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Token refresh timeout');
      });

      print('📡 Refresh response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));

        // ✅ Update access token only
        await _saveAccessToken(data['accessToken'] ?? '');

        print('✅ Token refreshed successfully');
        return data;
      } else if (response.statusCode == 401) {
        // Refresh token expired, need to login again
        await logout();
        throw Exception('Session expired. Please login again');
      } else {
        throw Exception('Token refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Token refresh error: $e');
      throw Exception('Token refresh error: $e');
    }
  }

  Future<Map<String, dynamic>?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      if (currentPassword.isEmpty) {
        throw Exception('Current password is required');
      }

      if (newPassword.isEmpty) {
        throw Exception('New password is required');
      }

      if (newPassword.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      if (newPassword != confirmPassword) {
        throw Exception('Passwords do not match');
      }

      if (currentPassword == newPassword) {
        throw Exception('New password must be different from current password');
      }

      final accessToken = await getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('User not authenticated');
      }

      print('🔐 Attempting to change password...');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        }),
      ).timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Change password request timeout');
      });

      print('📡 Change password response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
        print('✅ Password changed successfully');
        return data;
      } else if (response.statusCode == 401) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Invalid current password');
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Validation failed');
      } else {
        throw Exception('Change password failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Change password error: $e');
      throw Exception('Change password error: $e');
    }
  }

  // ✅ Logout - Revoke refresh token and clear local storage
  Future<bool> logout() async {
    try {
      final refreshToken = await getRefreshToken();

      if (refreshToken != null && refreshToken.isNotEmpty) {
        print('🔓 Logging out...');

        await http.post(
          Uri.parse('$baseUrl/api/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'refreshToken': refreshToken,
          }),
        ).timeout(Duration(seconds: 10));
      }

      // Clear all stored tokens and user data
      await _clearTokens();
      print('✅ Logout successful');
      return true;
    } catch (e) {
      print('❌ Logout error: $e');
      // Clear tokens even if logout request fails
      await _clearTokens();
      return false;
    }
  }

  // ✅ Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ✅ Get access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  // ✅ Get refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  // ✅ Get user email
  Future<String?> getUserEmail() async {
    return await _storage.read(key: _userEmailKey);
  }

  // ✅ Get user phone
  Future<String?> getUserPhone() async {
    return await _storage.read(key: _userPhoneKey);
  }

  // ✅ Get user roles
  Future<List<String>> getUserRoles() async {
    final rolesJson = await _storage.read(key: _userRolesKey);

    if (rolesJson == null || rolesJson.isEmpty) return [];

    try {
      final List<dynamic> roles = jsonDecode(rolesJson);
      return roles.map((role) => role.toString()).toList();
    } catch (e) {
      print('Error parsing roles: $e');
      return [];
    }
  }

  // ✅ Get user ID
  Future<int?> getUserId() async {
    final userIdStr = await _storage.read(key: _userIdKey);
    return userIdStr != null ? int.tryParse(userIdStr) : null;
  }

  // ✅ Get user full name from stored user data
  Future<String?> getUserFullName() async {
    return await _storage.read(key: _userName);
  }


  // ✅ Check if user has specific role
  Future<bool> hasRole(String role) async {
    final roles = await getUserRoles();
    return roles.contains(role.toUpperCase());
  }

  // ✅ Check if user is admin
  Future<bool> isAdmin() async {
    return await hasRole('ADMIN');
  }

  // ✅ Check if user is owner
  Future<bool> isOwner() async {
    return await hasRole('OWNER');
  }

  // ✅ Check if user is delivery
  Future<bool> isDelivery() async {
    return await hasRole('DELIVERY');
  }

  // ✅ Check if user is customer
  Future<bool> isCustomer() async {
    return await hasRole('CUSTOMER');
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  // ✅ Save tokens and user info locally
  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
    required String email,
    required String? phone,
    required List<dynamic> roles,
    required int userId,
    required String fullName,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userEmailKey, value: email);
    if (phone != null && phone.isNotEmpty) {
      await _storage.write(key: _userPhoneKey, value: phone);
    }
    await _storage.write(key: _userRolesKey, value: jsonEncode(roles));
    await _storage.write(key: _userIdKey, value: userId.toString());
    await _storage.write(key: _userName, value: fullName);
  }

  // ✅ Update access token only
  Future<void> _saveAccessToken(String accessToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
  }

  // ✅ Clear all stored tokens
  Future<void> _clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: _userPhoneKey);
    await _storage.delete(key: _userRolesKey);
    await _storage.delete(key: _userIdKey);
  }
}

// ============================================================================
// HTTP CLIENT WITH AUTO TOKEN REFRESH (Interceptor-like)
// ============================================================================

class AuthenticatedHttpClient extends http.BaseClient {
  final AuthService authService;
  final http.Client _inner;

  AuthenticatedHttpClient(this.authService) : _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await authService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'application/json';

    return _inner.send(request);
  }



  @override
  void close() {
    _inner.close();
    super.close();
  }
}