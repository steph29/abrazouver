import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/user.dart';

/// Persiste la session utilisateur pour éviter la déconnexion lors de la navigation web.
const _keyUser = 'abrazouver_user';
const _keyNotificationsLastSeen = 'abrazouver_notif_last_seen';

class SessionService {
  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  static Future<User?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyUser);
    if (json == null) return null;
    try {
      return User.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
    await prefs.remove(_keyNotificationsLastSeen);
  }

  static Future<int> getNotificationsLastSeenCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyNotificationsLastSeen) ?? 0;
  }

  static Future<void> setNotificationsLastSeenCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNotificationsLastSeen, count);
  }
}