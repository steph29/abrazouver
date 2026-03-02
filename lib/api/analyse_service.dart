import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class AnalyseService {
  /// Récupère les stats KPI, taux de remplissage par poste, liste des bénévoles.
  static Future<Map<String, dynamic>> getStats(
    int adminUserId, {
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = <String>[];
    if (dateFrom != null && dateFrom.isNotEmpty) query.add('dateFrom=$dateFrom');
    if (dateTo != null && dateTo.isNotEmpty) query.add('dateTo=$dateTo');
    final qs = query.isEmpty ? '' : '?${query.join('&')}';
    return ApiService.get(
      '/admin/analyse$qs',
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
  }

  /// Télécharge le fichier XLSX des bénévoles inscrits (+ bénévoles manuels pour l'année).
  static Future<Uint8List?> downloadExport(int adminUserId, {int? annee}) async {
    final qs = annee != null ? '?annee=$annee' : '';
    final url = Uri.parse('${ApiService.baseUrl}/admin/analyse/export$qs');
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
}
