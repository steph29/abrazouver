import 'package:flutter/material.dart';
import '../api/preferences_service.dart';
import '../api/session_service.dart';
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
  }

  static bool _themePreferencesLoaded = false;

  Future<void> _loadThemePreferences() async {
    if (_themePreferencesLoaded) return;
    try {
      final prefs = await PreferencesService.get();
      final primary = _parseColor(prefs['primaryColor']);
      final secondary = _parseColor(prefs['secondaryColor']);
      if (primary != null && secondary != null) {
        _themePreferencesLoaded = true;
        widget.onThemeReady(AppTheme.buildTheme(primary, secondary));
      }
    } catch (_) {}
  }

  Color? _parseColor(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return _colorFromHex(s);
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
        const ContactPage(),
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
      const NotificationsPage(),
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
          return ListTile(
            leading: Icon(
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle),
        leading: useRail
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
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
                        icon: Icon(e.icon),
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
