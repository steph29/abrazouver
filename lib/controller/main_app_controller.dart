import 'package:flutter/material.dart';
import '../api/contact_admin_service.dart';
import '../api/preferences_service.dart';
import '../api/session_service.dart';
import '../theme/theme_provider.dart';
import '../model/user.dart';
import '../theme/app_theme.dart';
import 'accueil_page.dart';
import 'admin_page.dart';
import 'analyse_page.dart';
import 'compte_page.dart';
import 'contact_page.dart';
import 'liens_utiles_page.dart';
import 'login_page.dart';
import 'mes_postes_page.dart';
import 'notifications_page.dart';
import 'places_libres_page.dart';
import 'preferences_page.dart';

const double _kDrawerWidth = 280;
const double _kBreakpointTablet = 600;

class MainAppController extends StatefulWidget {
  final User user;
  final void Function(ThemeData theme) onThemeReady;

  const MainAppController({super.key, required this.user, required this.onThemeReady});

  @override
  State<MainAppController> createState() => _MainAppControllerState();
}

class _MainAppControllerState extends State<MainAppController> {
  late User _user;
  String _currentTitle = 'Accueil';
  int _selectedIndex = 0;
  int _unreadNotificationsCount = 0;

  final List<({String title, IconData icon})> _mainItems = [
    (title: 'Accueil', icon: Icons.home_rounded),
    (title: 'Mes Postes', icon: Icons.work_rounded),
    (title: 'Places libres', icon: Icons.event_seat_rounded),
    (title: 'Contact', icon: Icons.contact_mail_rounded),
    (title: 'Liens utiles', icon: Icons.link_rounded),
  ];

  final List<({String title, IconData icon})> _adminItems = [
    (title: 'Admin', icon: Icons.admin_panel_settings_rounded),
    (title: 'Préférences', icon: Icons.palette_rounded),
    (title: 'Analyse', icon: Icons.analytics_rounded),
    (title: 'Notifications', icon: Icons.notifications_rounded),
  ];

  List<({String title, IconData icon})> get _allItems => [
    ..._mainItems,
    (title: 'Mon compte', icon: Icons.person_rounded),
    if (_user.isAdmin) ..._adminItems,
  ];

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadThemePreferences();
    if (_user.isAdmin) _loadNotificationsBadge();
  }

  static bool _themePreferencesLoaded = false;
  static bool _logoPreferencesLoaded = false;

  Future<void> _loadThemePreferences() async {
    try {
      final prefs = await PreferencesService.get();
      final primary = _parseColor(prefs['primaryColor']);
      final secondary = _parseColor(prefs['secondaryColor']);
      if (primary != null && secondary != null && !_themePreferencesLoaded) {
        _themePreferencesLoaded = true;
        widget.onThemeReady(AppTheme.buildTheme(primary, secondary));
      }
      if (!_logoPreferencesLoaded && mounted) {
        _logoPreferencesLoaded = true;
        final logo = prefs['logo'] as String?;
        AppThemeScope.maybeOf(context)?.updateLogo(logo);
      }
    } catch (_) {}
  }

  Color? _parseColor(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return _colorFromHex(s);
  }

  Future<void> _loadNotificationsBadge() async {
    try {
      final count = await ContactAdminService.getCount(_user.id);
      final lastSeen = await SessionService.getNotificationsLastSeenCount();
      final unread = count > lastSeen ? count - lastSeen : 0;
      if (mounted) setState(() => _unreadNotificationsCount = unread);
    } catch (_) {
      if (mounted) setState(() => _unreadNotificationsCount = 0);
    }
  }

  void _onNotificationsViewed(int count) async {
    await SessionService.setNotificationsLastSeenCount(count);
    if (mounted) setState(() => _unreadNotificationsCount = 0);
  }

  Color _colorFromHex(String hex) {
    String s = hex.startsWith('#') ? hex.substring(1) : hex;
    if (s.length != 6) return AppColors.primary;
    final r = int.tryParse(s.substring(0, 2), radix: 16);
    final g = int.tryParse(s.substring(2, 4), radix: 16);
    final b = int.tryParse(s.substring(4, 6), radix: 16);
    if (r == null || g == null || b == null) return AppColors.primary;
    return Color.fromARGB(255, r, g, b);
  }

  Widget _buildPageForIndex(int index) {
    if (index < _mainItems.length) {
      final pages = [
        const AccueilPage(),
        MesPostesPage(user: _user),
        PlacesLibresPage(user: _user),
        ContactPage(user: _user),
        const LiensUtilesPage(),
      ];
      return pages[index];
    }
    final compteIndex = _mainItems.length;
    if (index == compteIndex) {
      return ComptePage(
        user: _user,
        onUserUpdated: (u) => setState(() => _user = u),
      );
    }
    final adminPages = [
      const AdminPage(),
      PreferencesPage(user: _user),
      const AnalysePage(),
      NotificationsPage(user: _user, onViewed: _onNotificationsViewed),
    ];
    return adminPages[index - compteIndex - 1];
  }

  void _navigate(int index, {bool closeDrawer = false}) {
    setState(() {
      _selectedIndex = index;
      _currentTitle = _allItems[index].title;
    });
    if (closeDrawer) {
      Navigator.pop(context);
    }
    if (_user.isAdmin) _loadNotificationsBadge();
  }

  void _logout() {
    SessionService.clearUser();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginPage(onThemeReady: widget.onThemeReady)),
      (route) => false,
    );
  }

  Widget _buildDrawerContent() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _user.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _user.email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        ...List.generate(_allItems.length, (i) {
          final item = _allItems[i];
          final           showBadge = item.title == 'Notifications' && _unreadNotificationsCount > 0;
          return ListTile(
            leading: showBadge
                ? Badge(
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    label: Text('$_unreadNotificationsCount', style: const TextStyle(fontSize: 10)),
                    child: Icon(
                      item.icon,
                      color: _selectedIndex == i ? Theme.of(context).colorScheme.primaryContainer : AppColors.textSecondary,
                    ),
                  )
                : Icon(
                    item.icon,
                    color: _selectedIndex == i ? Theme.of(context).colorScheme.primaryContainer : AppColors.textSecondary,
                  ),
            title: Text(
              item.title,
              style: TextStyle(
                fontWeight: _selectedIndex == i ? FontWeight.w600 : FontWeight.normal,
                color: _selectedIndex == i ? Theme.of(context).colorScheme.primaryContainer : AppColors.textPrimary,
              ),
            ),
            selected: _selectedIndex == i,
            onTap: () => _navigate(i, closeDrawer: true),
          );
        }),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
          title: const Text('Déconnexion'),
          onTap: _logout,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _kBreakpointTablet;
    final useRail = isWide;

    final scope = AppThemeScope.maybeOf(context);
    final logoUri = scope?.logoDataUri;
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle),
        leading: useRail
            ? (logoUri != null && logoUri.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Center(child: imageFromDataUri(logoUri, height: 36, width: 36)),
                  )
                : null)
            : Builder(
                builder: (ctx) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (logoUri != null && logoUri.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: imageFromDataUri(logoUri, height: 36, width: 36),
                      ),
                    IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ],
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      drawer: useRail
          ? null
          : Drawer(
              width: _kDrawerWidth,
              child: _buildDrawerContent(),
            ),
      body: Row(
        children: [
          if (useRail)
            NavigationRail(
              extended: MediaQuery.of(context).size.width >= 800,
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                      tooltip: 'Déconnexion',
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                    if (MediaQuery.of(context).size.width >= 800)
                      const Text(
                        'Déconnexion',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              leading: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                      child: Text(
                        (_user.prenom.isNotEmpty
                                ? _user.prenom[0]
                                : _user.email[0])
                            .toUpperCase(),
                        style: TextStyle(color: Theme.of(context).colorScheme.primaryContainer),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (MediaQuery.of(context).size.width >= 800)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _user.prenom,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => _navigate(i),
              destinations: [
                ..._mainItems.map((e) => NavigationRailDestination(
                      icon: Icon(e.icon),
                      label: Text(e.title),
                    )),
                const NavigationRailDestination(
                  icon: Icon(Icons.person_rounded),
                  label: Text('Mon compte'),
                ),
                if (_user.isAdmin)
                  ..._adminItems.map((e) => NavigationRailDestination(
                        icon: e.title == 'Notifications' && _unreadNotificationsCount > 0
                            ? Badge(
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                label: Text('$_unreadNotificationsCount', style: const TextStyle(fontSize: 10)),
                                child: Icon(e.icon),
                              )
                            : Icon(e.icon),
                        label: Text(e.title),
                      )),
              ],
            ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: _buildPageForIndex(_selectedIndex),
            ),
          ),
        ],
      ),
    );
  }
}
