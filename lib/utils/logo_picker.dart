import 'dart:typed_data';

import 'logo_picker_stub.dart'
    if (dart.library.html) 'logo_picker_web.dart' as impl;

Future<Uint8List?> pickImageBytes({int maxBytes = 2 * 1024 * 1024}) =>
    impl.pickImageBytes(maxBytes: maxBytes);

/// Sélectionne un fichier quelconque (pièce jointe). Max 5 Mo par défaut.
Future<({Uint8List bytes, String name})?> pickFileBytes({int maxBytes = 5 * 1024 * 1024}) =>
    impl.pickFileBytes(maxBytes: maxBytes);
