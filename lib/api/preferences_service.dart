import 'api_service.dart';

class PreferencesService {
  /// Récupère les préférences (thème) - public
  static Future<Map<String, dynamic>> get() async {
    return ApiService.get('/preferences');
  }

  /// Met à jour les préférences - admin uniquement (X-User-Id requis)
  /// logo: data URI pour ajouter/modifier, ou passer removeLogo: true pour supprimer
  static Future<Map<String, dynamic>> update(
    int userId, {
    String? primaryColor,
    String? secondaryColor,
    String? logo,
    bool removeLogo = false,
    String? contactEmail,
    String? accueilTitre,
    String? accueilDescription,
  }) async {
    final body = <String, dynamic>{};
    if (primaryColor != null) body['primaryColor'] = primaryColor;
    if (secondaryColor != null) body['secondaryColor'] = secondaryColor;
    if (removeLogo) body['logo'] = null;
    else if (logo != null) body['logo'] = logo;
    if (contactEmail != null) body['contactEmail'] = contactEmail;
    if (accueilTitre != null) body['accueilTitre'] = accueilTitre;
    if (accueilDescription != null) body['accueilDescription'] = accueilDescription;
    return ApiService.put(
      '/preferences',
      body,
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }
}
