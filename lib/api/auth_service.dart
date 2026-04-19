import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    return ApiService.post('/auth/login', {
      'email': email,
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nom,
    required String prenom,
  }) async {
    return ApiService.post('/auth/register', {
      'email': email,
      'password': password,
      'nom': nom,
      'prenom': prenom,
    });
  }

  static Future<Map<String, dynamic>> getProfile(int userId) async {
    return ApiService.get('/auth/profile/$userId');
  }

  static Future<Map<String, dynamic>> updateProfile(
    int userId, {
    String? nom,
    String? prenom,
    String? email,
    String? telephone,
    bool? twoFactorEnabled,
  }) async {
    final data = <String, dynamic>{};
    if (nom != null) data['nom'] = nom;
    if (prenom != null) data['prenom'] = prenom;
    if (email != null) data['email'] = email;
    if (telephone != null) data['telephone'] = telephone;
    if (twoFactorEnabled != null) data['twoFactorEnabled'] = twoFactorEnabled;
    return ApiService.put('/auth/profile/$userId', data);
  }

  static Future<Map<String, dynamic>> setup2FA(int userId) async {
    return ApiService.post('/auth/2fa/setup/$userId', {});
  }

  static Future<void> confirm2FA(int userId, String code) async {
    await ApiService.post('/auth/2fa/confirm/$userId', {'code': code});
  }

  static Future<void> disable2FA(int userId, String code) async {
    await ApiService.post('/auth/2fa/disable/$userId', {'code': code});
  }

  static Future<Map<String, dynamic>> verify2FA(String tempToken, String code) async {
    return ApiService.post('/auth/2fa/verify', {
      'tempToken': tempToken,
      'code': code,
    });
  }

  /// Demande de réinitialisation du mot de passe (envoi email avec lien)
  static Future<Map<String, dynamic>> forgotPassword(String email, {String? appBaseUrl}) async {
    final body = <String, dynamic>{'email': email};
    if (appBaseUrl != null) body['appBaseUrl'] = appBaseUrl;
    return ApiService.post('/auth/forgot-password', body);
  }

  /// Réinitialisation du mot de passe avec le token du lien email
  static Future<void> resetPassword(String token, String newPassword) async {
    await ApiService.post('/auth/reset-password', {
      'token': token,
      'newPassword': newPassword,
    });
  }

  /// Modification du mot de passe (utilisateur connecté)
  static Future<void> updatePassword(int userId, String currentPassword, String newPassword) async {
    await ApiService.put(
      '/auth/password/$userId',
      {'currentPassword': currentPassword, 'newPassword': newPassword},
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  /// Liste des membres du foyer (connecté).
  static Future<List<Map<String, dynamic>>> getFamilyMembers(int userId) async {
    final r = await ApiService.get(
      '/auth/family',
      extraHeaders: {'X-User-Id': userId.toString()},
    );
    final list = r['members'] as List?;
    return (list ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Ajoute un bénévole famille (titulaire uniquement).
  /// [email] et [password] optionnels : sans compte séparé, le membre est géré par le titulaire uniquement.
  static Future<Map<String, dynamic>> addFamilyMember(
    int userId, {
    String? email,
    String? password,
    required String nom,
    required String prenom,
  }) async {
    final body = <String, dynamic>{
      'nom': nom,
      'prenom': prenom,
    };
    final em = email?.trim() ?? '';
    if (em.isNotEmpty) {
      body['email'] = em;
      body['password'] = password ?? '';
    }
    return ApiService.post(
      '/auth/family/member',
      body,
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }

  /// Retire un membre familial (titulaire uniquement).
  static Future<void> removeFamilyMember(int userId, int memberId) async {
    await ApiService.delete(
      '/auth/family/member/$memberId',
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }
}

