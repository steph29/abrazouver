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

  /// Télécharge le fichier XLSX des bénévoles inscrits.
  static Future<Uint8List?> downloadExport(int adminUserId) async {
    final url = Uri.parse('${ApiService.baseUrl}/admin/analyse/export');
    final resp = await http.get(
      url,
      headers: {'X-User-Id': adminUserId.toString()},
    );
    if (resp.statusCode != 200) return null;
    return resp.bodyBytes;
  }
}
