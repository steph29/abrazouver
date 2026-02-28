import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Sélection de fichier quelconque via input HTML natif (pièce jointe).
Future<({Uint8List bytes, String name})?> pickFileBytes({int maxBytes = 5 * 1024 * 1024}) async {
  final input = html.FileUploadInputElement()
    ..accept = ''
    ..multiple = false;
  input.click();

  final completer = Completer<({Uint8List bytes, String name})?>();
  void handler(html.Event e) {
    input.removeEventListener('change', handler);
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files[0];
    if ((file.size ?? 0) > maxBytes) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      try {
        final result = reader.result;
        if (result == null) {
          completer.complete(null);
          return;
        }
        Uint8List? data;
        if (result is Uint8List) {
          data = result;
        } else if (result is ByteBuffer) {
          data = Uint8List.view(result);
        }
        if (data != null) {
          completer.complete((bytes: data, name: file.name ?? 'piece_jointe'));
        } else {
          completer.complete(null);
        }
      } catch (_) {
        completer.complete(null);
      }
    });
    reader.readAsArrayBuffer(file);
  }
  input.addEventListener('change', handler);
  return completer.future;
}

/// Sélection de fichier image via input HTML natif.
/// Évite le bug LateInitializationError de file_picker en build web production.
Future<Uint8List?> pickImageBytes({int maxBytes = 2 * 1024 * 1024}) async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png'
    ..multiple = false;
  input.click();

  final completer = Completer<Uint8List?>();
  void handler(html.Event e) {
    input.removeEventListener('change', handler);
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files[0];
    if ((file.size ?? 0) > maxBytes) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      try {
        final result = reader.result;
        if (result == null) {
          completer.complete(null);
          return;
        }
        if (result is Uint8List) {
          completer.complete(result);
        } else if (result is ByteBuffer) {
          completer.complete(Uint8List.view(result));
        } else {
          completer.complete(null);
        }
      } catch (_) {
        completer.complete(null);
      }
    });
    reader.readAsArrayBuffer(file);
  }
  input.addEventListener('change', handler);
  return completer.future;
}
