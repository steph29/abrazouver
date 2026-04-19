import 'api_service.dart';

class InscriptionService {
  /// Mes inscriptions avec détails poste/créneau
  static Future<Map<String, dynamic>> getMesInscriptions(int userId) async {
    return ApiService.get(
      '/benevoles/inscriptions/me',
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  /// Inscriptions groupées par membre du foyer
  static Future<Map<String, dynamic>> getMesInscriptionsFamily(int userId) async {
    return ApiService.get(
      '/benevoles/inscriptions/me/family',
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  /// Inscription à un créneau ; [targetUserIds] pour inscrire un ou plusieurs membres (titulaire).
  static Future<Map<String, dynamic>> inscrire(
    int userId,
    int creneauId, {
    List<int>? targetUserIds,
  }) async {
    final body = <String, dynamic>{'creneauId': creneauId};
    if (targetUserIds != null && targetUserIds.isNotEmpty) {
      body['targetUserIds'] = targetUserIds;
    }
    return ApiService.post(
      '/benevoles/inscriptions',
      body,
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  /// Désinscription ; [targetUserId] pour annuler pour un membre (responsable).
  static Future<void> desinscrire(
    int userId,
    int creneauId, {
    int? targetUserId,
  }) async {
    var path = '/benevoles/inscriptions/$creneauId';
    if (targetUserId != null) {
      path += '?targetUserId=$targetUserId';
    }
    await ApiService.delete(
      path,
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }
}
