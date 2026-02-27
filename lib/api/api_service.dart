import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static String _baseUrl = 'http://localhost:3000/api';

  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      ...?extraHeaders,
    };
    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers.isNotEmpty ? headers : null,
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?extraHeaders,
    };
    final response = await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      ...?extraHeaders,
    };
    final response = await http.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers.isNotEmpty ? headers : null,
    );
    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {'success': true};
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'raw': response.body};
      }
    }
    String msg = response.body;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      msg = decoded['message'] as String? ?? msg;
    } catch (_) {}
    throw ApiException(response.statusCode, msg.isNotEmpty ? msg : 'Erreur serveur');
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException ($statusCode): $message';
}
