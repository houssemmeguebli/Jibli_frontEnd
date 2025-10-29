import 'package:flutter/material.dart';
import 'package:frontend/features/delievery/presentation/pages/delivery_main_layout.dart';
import 'package:frontend/features/owner/presentation/pages/owner_main_layout.dart';
import 'package:frontend/features/admin/presentation/pages/admin_main_layout.dart';
import 'core/theme/theme.dart';
import 'features/customer/presentation/pages/customer_main_layout.dart';

void main() {
  runApp(const JibliApp());
}

class JibliApp extends StatelessWidget {
  const JibliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jibli',
      theme: AppTheme.lightTheme,
      home: const AdminMainLayout(),
      debugShowCheckedModeBanner: false,
    );
  }
}
