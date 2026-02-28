import 'dart:convert';

import 'api_service.dart';

class ContactService {
  /// Envoyer un message depuis la page Contact.
  /// attachment: {bytes, name} ou null.
  static Future<Map<String, dynamic>> sendMessage({
    required int userId,
    required String email,
    required String subject,
    required String body,
    ({List<int> bytes, String name})? attachment,
  }) async {
    final bodyData = <String, dynamic>{
      'email': email,
      'subject': subject,
      'body': body,
    };
    if (attachment != null) {
      bodyData['attachmentBase64'] = base64Encode(attachment.bytes);
      bodyData['attachmentFileName'] = attachment.name;
    }
    return ApiService.post(
      '/contact',
      bodyData,
      extraHeaders: {'X-User-Id': userId.toString()},
    );
  }
}
