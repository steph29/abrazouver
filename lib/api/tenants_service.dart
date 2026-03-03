import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class TenantsService {
  /// Liste des clients (nécessite le secret super-admin)
  static Future<List<Map<String, dynamic>>> getTenants(String secret) async {
    final data = await http.get(
      Uri.parse('${ApiService.baseUrl}/superadmin/tenants'),
      headers: {'X-Super-Admin-Secret': secret},
    );
    if (data.statusCode != 200) {
      throw ApiException(data.statusCode, _extractMessage(data.body));
    }
    final decoded = jsonDecode(data.body) as Map<String, dynamic>;
    final list = decoded['tenants'] as List?;
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  /// Ajoute un client
  static Future<Map<String, dynamic>> addTenant(
    String secret, {
    required String subdomain,
    required String clientName,
    required String dbHost,
    int dbPort = 3306,
    required String dbUser,
    required String dbPassword,
    required String dbName,
  }) async {
    final body = {
      'subdomain': subdomain,
      'clientName': clientName,
      'dbHost': dbHost,
      'dbPort': dbPort,
      'dbUser': dbUser,
      'dbPassword': dbPassword,
      'dbName': dbName,
    };
    final resp = await http.post(
      Uri.parse('${ApiService.baseUrl}/superadmin/tenants'),
      headers: {
        'Content-Type': 'application/json',
        'X-Super-Admin-Secret': secret,
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw ApiException(resp.statusCode, _extractMessage(resp.body));
  }

  /// Teste la connexion à une DB
  static Future<void> testConnection(
    String secret, {
    required String dbHost,
    int dbPort = 3306,
    required String dbUser,
    required String dbPassword,
    required String dbName,
  }) async {
    final body = {
      'dbHost': dbHost,
      'dbPort': dbPort,
      'dbUser': dbUser,
      'dbPassword': dbPassword,
      'dbName': dbName,
    };
    final resp = await http.post(
      Uri.parse('${ApiService.baseUrl}/superadmin/tenants/test'),
      headers: {
        'Content-Type': 'application/json',
        'X-Super-Admin-Secret': secret,
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, _extractMessage(resp.body));
    }
  }

  /// Modifie un client
  static Future<Map<String, dynamic>> updateTenant(
    String secret,
    int id, {
    required String subdomain,
    String? clientName,
    required String dbHost,
    int dbPort = 3306,
    required String dbUser,
    String? dbPassword,
    required String dbName,
  }) async {
    final body = <String, dynamic>{
      'subdomain': subdomain,
      'clientName': clientName ?? subdomain,
      'dbHost': dbHost,
      'dbPort': dbPort,
      'dbUser': dbUser,
      'dbName': dbName,
    };
    if (dbPassword != null && dbPassword.isNotEmpty) {
      body['dbPassword'] = dbPassword;
    }
    final resp = await http.put(
      Uri.parse('${ApiService.baseUrl}/superadmin/tenants/$id'),
      headers: {
        'Content-Type': 'application/json',
        'X-Super-Admin-Secret': secret,
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw ApiException(resp.statusCode, _extractMessage(resp.body));
  }

  /// Provisionnement SSL + nginx (certbot) pour tous les clients
  static Future<Map<String, dynamic>> provision(String secret) async {
    final resp = await http.post(
      Uri.parse('${ApiService.baseUrl}/superadmin/tenants/provision'),
      headers: {
        'Content-Type': 'application/json',
        'X-Super-Admin-Secret': secret,
      },
    );
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Supprime un client
  static Future<void> deleteTenant(String secret, int id) async {
    final resp = await http.delete(
      Uri.parse('${ApiService.baseUrl}/superadmin/tenants/$id'),
      headers: {'X-Super-Admin-Secret': secret},
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(resp.statusCode, _extractMessage(resp.body));
    }
  }

  static String _extractMessage(String body) {
    try {
      final d = jsonDecode(body) as Map?;
      return d?['message'] as String? ?? body;
    } catch (_) {
      return body;
    }
  }
}
