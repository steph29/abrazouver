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
}
