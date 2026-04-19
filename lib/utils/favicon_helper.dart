import 'favicon_helper_stub.dart'
    if (dart.library.html) 'favicon_helper_web.dart' as impl;

void setFavicon(String? dataUri) => impl.setFavicon(dataUri);
