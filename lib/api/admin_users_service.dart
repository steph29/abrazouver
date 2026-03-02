import 'api_service.dart';

class AdminUsersService {
  /// Liste de tous les utilisateurs inscrits (compte créé) et leur rôle admin
  static Future<List<Map<String, dynamic>>> getUsers(int adminUserId) async {
    final data = await ApiService.get(
      '/admin/users',
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
    final list = data['users'] as List?;
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  /// Met à jour le rôle admin d'un utilisateur
  static Future<void> setUserRole(int adminUserId, int targetUserId, bool isAdmin) async {
    await ApiService.put(
      '/admin/users/$targetUserId/role',
      {'isAdmin': isAdmin},
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
  }
}
