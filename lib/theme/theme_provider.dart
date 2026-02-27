import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Fournit un thème dynamique à toute l'app.
/// Permet de mettre à jour le thème (ex: après chargement des préférences).
class AppThemeScope extends InheritedWidget {
  final ThemeData theme;
  final void Function(ThemeData theme) updateTheme;

  const AppThemeScope({
    super.key,
    required this.theme,
    required this.updateTheme,
    required super.child,
  });

  static AppThemeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
  }

  @override
  bool updateShouldNotify(AppThemeScope old) => theme != old.theme;
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

/// Convertit une Color en hex #RRGGBB
String colorToHex(Color c) {
  return '#${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}';
}
