import 'package:http/http.dart' as http;

import 'api_service.dart';

class ContactAdminService {
  /// Nombre de messages (pour badge notifications).
  static Future<int> getCount(int adminUserId) async {
    final data = await ApiService.get(
      '/admin/contact-messages/count',
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
    if (data is Map && data['count'] != null) {
      return (data['count'] as num).toInt();
    }
    return 0;
  }

  /// Liste des messages reçus depuis la page Contact (admin).
  static Future<List<Map<String, dynamic>>> getMessages(int adminUserId) async {
    final data = await ApiService.get(
      '/admin/contact-messages',
      extraHeaders: {'X-User-Id': adminUserId.toString()},
    );
    final list = data is Map ? (data as Map<String, dynamic>)['messages'] : null;
    if (list is List) return List<Map<String, dynamic>>.from(list.map((e) => e as Map<String, dynamic>));
    return [];
  }

  /// Télécharge la pièce jointe d'un message (admin). Retourne null si erreur.
  static Future<({List<int> bytes, String name})?> downloadAttachment(
    int adminUserId,
    int messageId,
  ) async {
    final url = Uri.parse(
      '${ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '')}/api/admin/contact-messages/$messageId/attachment',
    );
    final resp = await http.get(
      url,
      headers: {'X-User-Id': adminUserId.toString()},
    );
    if (resp.statusCode != 200) return null;
    final name = resp.headers['content-disposition']?.contains('filename=') == true
        ? Uri.decodeComponent(resp.headers['content-disposition']!.split('filename=').last.trim().replaceAll('"', ''))
        : 'piece_jointe';
    return (bytes: resp.bodyBytes, name: name);
  }
}
