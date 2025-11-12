import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:frontend/features/delievery/presentation/pages/delivery_main_layout.dart';
import 'package:frontend/features/owner/presentation/pages/owner_main_layout.dart';
import 'package:frontend/features/admin/presentation/pages/admin_main_layout.dart';
import 'core/theme/theme.dart';
import 'core/presentation/pages/splash_screen.dart';
import 'features/customer/presentation/pages/customer_main_layout.dart';
import 'features/auth/pages/login_page.dart';
import 'core/services/auth_service.dart';
import 'firebase_options.dart';
import 'core/services/firebase_messaging_service.dart';

// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Background message received: ${message.messageId}');
}

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve native splash while app initializes
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    print('🔧 Initializing Firebase...');

    // Initialize Firebase
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized');
    }

    // Set background message handler BEFORE using Firebase Messaging
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print('✅ Background handler registered');

    // Initialize Firebase Messaging Service (this auto-saves FCM token)
    await FirebaseMessagingService.initialize();
    print('✅ Firebase Messaging Service initialized');
  } catch (e) {
    print('❌ Initialization error: $e');
  }

  runApp(const JibliApp());
}

class JibliApp extends StatefulWidget {
  const JibliApp({super.key});

  @override
  State<JibliApp> createState() => _JibliAppState();
}

class _JibliAppState extends State<JibliApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      print('🚀 App initializing...');

      // Small delay to ensure all initialization is complete
      await Future.delayed(const Duration(milliseconds: 500));

      print('✅ App initialization complete');

      // Remove the native splash screen
      if (mounted) {
        FlutterNativeSplash.remove();
      }
    } catch (e) {
      print('❌ Error during initialization: $e');
      if (mounted) {
        FlutterNativeSplash.remove();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jibli',
      theme: AppTheme.lightTheme,
      home: const _HomeWithLayout(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _HomeWithLayout extends StatefulWidget {
  const _HomeWithLayout();

  @override
  State<_HomeWithLayout> createState() => _HomeWithLayoutState();
}

class _HomeWithLayoutState extends State<_HomeWithLayout> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Widget? _targetScreen;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _checkAuthAndRedirect();
  }

  Future<void> _checkAuthAndRedirect() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      
      if (!isLoggedIn) {
        setState(() {
          _targetScreen = LoginPage();
          _isLoading = false;
        });
        return;
      }

      final roles = await _authService.getUserRoles();
      
      if (roles.contains('ADMIN')) {
        _targetScreen = const AdminMainLayout();
      } else if (roles.contains('OWNER')) {
        _targetScreen = const OwnerMainLayout();
      } else if (roles.contains('DELIVERY')) {
        _targetScreen = const DeliveryMainLayout();
      } else {
        _targetScreen = const CustomerMainLayout();
      }
    } catch (e) {
      _targetScreen = LoginPage();
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show splash screen only for first app open
    if (_showSplash && _targetScreen != null) {
      return SplashScreen(nextScreen: _targetScreen!);
    }

    return _targetScreen!;
  }
}