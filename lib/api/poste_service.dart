import 'api_service.dart';

class PosteService {
  static Future<Map<String, dynamic>> getPostes() async {
    return ApiService.get('/postes');
  }

  static Future<Map<String, dynamic>> getPoste(int id) async {
    return ApiService.get('/postes/$id');
  }

  /// Liste pour la gestion (admin : tous les postes de l’événement ; référent : postes assignés).
  static Future<Map<String, dynamic>> getPostesForManagement(int userId) async {
    return ApiService.get(
      '/admin/postes',
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  static Future<Map<String, dynamic>> createPoste(int userId, Map<String, dynamic> data) async {
    return ApiService.post(
      '/admin/postes',
      data,
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  static Future<Map<String, dynamic>> updatePoste(int userId, int id, Map<String, dynamic> data) async {
    return ApiService.put(
      '/admin/postes/$id',
      data,
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  static Future<void> deletePoste(int userId, int id) async {
    await ApiService.delete(
      '/admin/postes/$id',
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }
}
