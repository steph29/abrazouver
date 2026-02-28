import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart' as impl;

/// Déclenche le téléchargement d'un fichier. Web : blob + anchor. Mobile : sauvegarde temp + ouverture.
Future<bool> downloadFile(List<int> bytes, String filename) => impl.downloadFile(bytes, filename);
