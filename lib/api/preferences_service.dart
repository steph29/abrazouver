import 'api_service.dart';

class PreferencesService {
  /// Récupère les préférences (thème) - public
  static Future<Map<String, dynamic>> get() async {
    return ApiService.get('/preferences');
  }

  /// Met à jour les préférences - admin uniquement (X-User-Id requis)
  static Future<Map<String, dynamic>> update(
    int userId, {
    String? primaryColor,
    String? secondaryColor,
  }) async {
    final body = <String, dynamic>{};
    if (primaryColor != null) body['primaryColor'] = primaryColor;
    if (secondaryColor != null) body['secondaryColor'] = secondaryColor;
    return ApiService.put(
      '/preferences',
      body,
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }
}
