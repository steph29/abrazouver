import 'api_service.dart';

class InscriptionService {
  static Future<Map<String, dynamic>> inscrire(
    int userId,
    int creneauId,
  ) async {
    return ApiService.post(
      '/benevoles/inscriptions',
      {'creneauId': creneauId},
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  static Future<void> desinscrire(int userId, int creneauId) async {
    await ApiService.delete(
      '/benevoles/inscriptions/$creneauId',
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }
}
