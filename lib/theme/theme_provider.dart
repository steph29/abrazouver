import 'dart:convert';

import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Fournit un thème et logo dynamiques à toute l'app.
class AppThemeScope extends InheritedWidget {
  final ThemeData theme;
  final String? logoDataUri;
  final void Function(ThemeData theme) updateTheme;
  final void Function(String? logo) updateLogo;

  const AppThemeScope({
    super.key,
    required this.theme,
    required this.logoDataUri,
    required this.updateTheme,
    required this.updateLogo,
    required super.child,
  });

  static AppThemeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
  }

  @override
  bool updateShouldNotify(AppThemeScope old) =>
      theme != old.theme || logoDataUri != old.logoDataUri;
}

/// Parse une couleur hex (#RRGGBB ou RRGGBB)
Color colorFromHex(String hex) {
  String s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length != 6) return AppColors.primary;
  final r = int.tryParse(s.substring(0, 2), radix: 16);
  final g = int.tryParse(s.substring(2, 4), radix: 16);
  final b = int.tryParse(s.substring(4, 6), radix: 16);
  if (r == null || g == null || b == null) return AppColors.primary;
  return Color.fromARGB(255, r, g, b);
}

/// Affiche une image à partir d'une data URI (data:image/png;base64,...)
Widget imageFromDataUri(String? dataUri, {double? width, double? height, BoxFit fit = BoxFit.contain}) {
  if (dataUri == null || dataUri.isEmpty) return const SizedBox.shrink();
  try {
    final base64 = dataUri.contains(',') ? dataUri.split(',').last : dataUri;
    final bytes = base64Decode(base64);
    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  } catch (_) {
    return const SizedBox.shrink();
  }
}

/// Convertit une Color en hex #RRGGBB
String colorToHex(Color c) {
  return '#${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}';
}
