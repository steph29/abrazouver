import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List?> pickImageBytes({int maxBytes = 2 * 1024 * 1024}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final bytes = result.files.single.bytes;
  if (bytes == null || bytes.length > maxBytes) return null;
  return bytes;
}

Future<({Uint8List bytes, String name})?> pickFileBytes({int maxBytes = 5 * 1024 * 1024}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null || bytes.length > maxBytes) return null;
  final name = file.name;
  return (bytes: bytes, name: name.isNotEmpty ? name : 'piece_jointe');
}
