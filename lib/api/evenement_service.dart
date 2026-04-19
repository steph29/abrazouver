import 'api_service.dart';

class EvenementService {
  /// Événement actif (public)
  static Future<Map<String, dynamic>> getCurrent() async {
    return ApiService.get('/evenements/current');
  }

  static Future<Map<String, dynamic>> listAdmin(int userId) async {
    return ApiService.get(
      '/admin/evenements',
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  static Future<Map<String, dynamic>> create(
    int userId, {
    required String nom,
    String? description,
    required DateTime dateDebut,
    required DateTime dateFin,
    int? annee,
    List<String>? notes,
  }) async {
    return ApiService.post(
      '/admin/evenements',
      {
        'nom': nom,
        'description': description,
        'dateDebut': dateDebut.toUtc().toIso8601String(),
        'dateFin': dateFin.toUtc().toIso8601String(),
        'annee': annee,
        'notes': notes ?? [],
      },
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  static Future<Map<String, dynamic>> update(
    int userId,
    int id, {
    String? nom,
    String? description,
    DateTime? dateDebut,
    DateTime? dateFin,
    int? annee,
    List<String>? notes,
  }) async {
    final body = <String, dynamic>{};
    if (nom != null) body['nom'] = nom;
    if (description != null) body['description'] = description;
    if (dateDebut != null) body['dateDebut'] = dateDebut.toUtc().toIso8601String();
    if (dateFin != null) body['dateFin'] = dateFin.toUtc().toIso8601String();
    if (annee != null) body['annee'] = annee;
    if (notes != null) body['notes'] = notes;
    return ApiService.put(
      '/admin/evenements/$id',
      body,
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  static Future<Map<String, dynamic>> activate(int userId, int id) async {
    return ApiService.post(
      '/admin/evenements/$id/activate',
      {},
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  static Future<void> delete(int userId, int id) async {
    await ApiService.delete(
      '/admin/evenements/$id',
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }
}
