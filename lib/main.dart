import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api/api_service.dart';
import 'api/session_service.dart';
import 'controller/login_page.dart';
import 'controller/main_app_controller.dart';
import 'model/user.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    try {
      final uri = Uri.base.resolve('config.json');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        final baseUrl = data?['apiBaseUrl'] as String?;
        if (baseUrl != null && baseUrl.isNotEmpty) {
          ApiService.setBaseUrl(baseUrl);
        }
      }
    } catch (_) {}
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Abrazouver',
      theme: AppTheme.lightTheme,
      home: const _InitialPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Charge la page initiale : MainApp si session sauvegardée, sinon Login.
class _InitialPage extends StatefulWidget {
  const _InitialPage();

  @override
  State<_InitialPage> createState() => _InitialPageState();
}

class _InitialPageState extends State<_InitialPage> {
  Future<User?> _loadSession() => SessionService.loadUser();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _loadSession(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user != null) {
          return MainAppController(user: user);
        }
        return const LoginPage();
      },
    );
  }
}
