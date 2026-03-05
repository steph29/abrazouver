import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class AnalyseService {
  /// Récupère les stats KPI, taux de remplissage par poste, liste des bénévoles.
  static Future<Map<String, dynamic>> getStats(
    int adminUserId, {
    String? dateFrom,
    String? dateTo,
    List<int>? posteIds,
  }) async {
    final query = <String>[];
    if (dateFrom != null && dateFrom.isNotEmpty) query.add('dateFrom=$dateFrom');
    if (dateTo != null && dateTo.isNotEmpty) query.add('dateTo=$dateTo');
    if (posteIds != null && posteIds.isNotEmpty) {
      query.add('posteIds=${posteIds.join(',')}');
    }
    final qs = query.isEmpty ? '' : '?${query.join('&')}';
    return ApiService.get(
      '/admin/analyse$qs',
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
  }

  /// Télécharge le fichier XLSX des bénévoles inscrits (+ bénévoles manuels pour l'année).
  static Future<Uint8List?> downloadExport(
    int adminUserId, {
    int? annee,
    String? dateFrom,
    String? dateTo,
    List<int>? posteIds,
  }) async {
    final params = <String, String>{};
    if (annee != null) params['annee'] = annee.toString();
    if (dateFrom != null && dateFrom.isNotEmpty) params['dateFrom'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['dateTo'] = dateTo;
    if (posteIds != null && posteIds.isNotEmpty) {
      params['posteIds'] = posteIds.join(',');
    }
    final url = params.isEmpty
        ? Uri.parse('${ApiService.baseUrl}/admin/analyse/export')
        : Uri.parse('${ApiService.baseUrl}/admin/analyse/export').replace(queryParameters: params);
    final resp = await http.get(
      url,
      headers: {'X-User-Id': adminUserId.toString()},
    );
    if (resp.statusCode != 200) return null;
    return resp.bodyBytes;
  }

  /// Liste des bénévoles inscrits à la main pour une année.
  static Future<List<Map<String, dynamic>>> getBenevolesManuels(int adminUserId, int annee) async {
    final data = await ApiService.get(
      '/admin/analyse/benevoles-manuels?annee=$annee',
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
    final list = data['benevoles'] as List?;
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  /// Ajoute un bénévole inscrit à la main.
  static Future<Map<String, dynamic>> addBenevoleManuel(
    int adminUserId, {
    required String nom,
    required String prenom,
    int? annee,
  }) async {
    final an = annee ?? DateTime.now().year;
    return ApiService.post(
      '/admin/analyse/benevoles-manuels',
      {'nom': nom, 'prenom': prenom, 'annee': an},
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
  }

  /// Supprime un bénévole inscrit à la main.
  static Future<void> deleteBenevoleManuel(int adminUserId, int id) async {
    await ApiService.delete(
      '/admin/analyse/benevoles-manuels/$id',
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
  }

  /// Liste des bénévoles pour envoi de rappels (avec email).
  static Future<List<Map<String, dynamic>>> getRappelsBenevoles(int adminUserId) async {
    final data = await ApiService.get(
      '/admin/analyse/rappels/benevoles',
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
    final list = data['benevoles'] as List?;
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  /// Liste des templates email pour rappels.
  static Future<List<Map<String, dynamic>>> getRappelsTemplates(int adminUserId) async {
    final data = await ApiService.get(
      '/admin/analyse/rappels/templates',
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
    final list = data['templates'] as List?;
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  /// Envoie les emails de rappel.
  static Future<Map<String, dynamic>> sendRappels(
    int adminUserId, {
    required String subject,
    required String body,
    List<int>? recipientIds,
    bool sendToAll = false,
    String? templateId,
    String? attachmentName,
    String? attachmentBase64,
  }) async {
    final bodyData = <String, dynamic>{
      'subject': subject,
      'body': body,
      'sendToAll': sendToAll,
      if (templateId != null) 'templateId': templateId,
      if (recipientIds != null && recipientIds.isNotEmpty) 'recipientIds': recipientIds,
    };
    if (attachmentName != null && attachmentBase64 != null) {
      bodyData['attachment'] = {'name': attachmentName, 'content': attachmentBase64};
    }
    return ApiService.post(
      '/admin/analyse/rappels/send',
      bodyData,
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
  }
}
