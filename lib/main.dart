import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api/api_service.dart';
import 'api/session_service.dart';
import 'controller/login_page.dart';
import 'controller/main_app_controller.dart';
import 'controller/reset_password_page.dart';
import 'controller/tenants_config_page.dart';
import 'model/user.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    final host = Uri.base.host;
    // app.xxx ou www.app.xxx → api.xxx (multi-tenant)
    String? apiHost;
    if (host.startsWith('app.')) {
      apiHost = host.replaceFirst(RegExp(r'^app\.'), 'api.');
    } else if (host.startsWith('www.app.')) {
      apiHost = host.replaceFirst(RegExp(r'^www\.app\.'), 'api.');
    }
    if (apiHost != null) {
      // Toujours HTTPS en prod (évite erreur CORS sur redirection http→https)
      final scheme = host.contains('localhost') ? Uri.base.scheme : 'https';
      ApiService.setBaseUrl('$scheme://$apiHost/api');
    } else {
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
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeData _theme = AppTheme.lightTheme;
  String? _logo;

  void _updateTheme(ThemeData theme) {
    setState(() => _theme = theme);
  }

  void _updateLogo(String? logo) {
    setState(() => _logo = logo);
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      theme: _theme,
      logoDataUri: _logo,
      updateTheme: _updateTheme,
      updateLogo: _updateLogo,
      child: MaterialApp(
        title: 'Abrazouvert',
        theme: _theme,
        home: _InitialPage(onThemeReady: _updateTheme),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Charge la page initiale : MainApp si session sauvegardée, sinon Login.
class _InitialPage extends StatefulWidget {
  final void Function(ThemeData theme) onThemeReady;

  const _InitialPage({required this.onThemeReady});

  @override
  State<_InitialPage> createState() => _InitialPageState();
}

class _InitialPageState extends State<_InitialPage> {
  static bool get _isAdminHost {
    if (!kIsWeb) return false;
    final host = Uri.base.host;
    return host.contains('.admin.') || host.startsWith('admin.');
  }

  Future<User?> _loadSession() => SessionService.loadUser();

  @override
  Widget build(BuildContext context) {
    if (_isAdminHost) {
      return TenantsConfigPage(onThemeReady: widget.onThemeReady);
    }
    if (kIsWeb) {
      final path = Uri.base.path;
      final token = Uri.base.queryParameters['token'];
      if (path.contains('reset-password') && token != null && token.isNotEmpty) {
        return ResetPasswordPage(token: token, onThemeReady: widget.onThemeReady);
      }
    }
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
          return MainAppController(
            user: user,
            onThemeReady: widget.onThemeReady,
          );
        }
        return LoginPage(onThemeReady: widget.onThemeReady);
      },
    );
  }
}
