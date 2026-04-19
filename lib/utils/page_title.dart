import 'page_title_stub.dart'
    if (dart.library.html) 'page_title_web.dart' as impl;

void setPageTitle(String title) => impl.setPageTitle(title);
