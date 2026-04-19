import 'dart:html' as html;

void setFavicon(String? dataUri) {
  final href = dataUri != null && dataUri.trim().isNotEmpty
      ? dataUri.trim()
      : 'favicon.png';
  html.document.querySelectorAll('link[rel="icon"]').forEach((e) {
    (e as html.LinkElement).href = href;
  });
  html.document.querySelectorAll('link[rel="apple-touch-icon"]').forEach((e) {
    (e as html.LinkElement).href = href;
  });
}
