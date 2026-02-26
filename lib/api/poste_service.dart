import 'api_service.dart';

class PosteService {
  static Future<Map<String, dynamic>> getPostes() async {
    return ApiService.get('/postes');
  }

  static Future<Map<String, dynamic>> getPoste(int id) async {
    return ApiService.get('/postes/$id');
  }

  static Future<Map<String, dynamic>> createPoste(Map<String, dynamic> data) async {
    return ApiService.post('/admin/postes', data);
  }

  static Future<Map<String, dynamic>> updatePoste(int id, Map<String, dynamic> data) async {
    return ApiService.put('/admin/postes/$id', data);
  }

  static Future<void> deletePoste(int id) async {
    await ApiService.delete('/admin/postes/$id');
  }
}
