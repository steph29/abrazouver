import 'package:flutter/material.dart';
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

const double _kDrawerWidth = 280;
const double _kBreakpointTablet = 600;

class MainAppController extends StatefulWidget {
  final User user;

  const MainAppController({super.key, required this.user});

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
  }

  Widget _buildPageForIndex(int index) {
    if (index < _mainItems.length) {
      final pages = [
        const AccueilPage(),
        const MesPostesPage(),
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
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Widget _buildDrawerContent() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            color: AppColors.primaryDark,
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
              color: _selectedIndex == i ? AppColors.primaryDark : AppColors.textSecondary,
            ),
            title: Text(
              item.title,
              style: TextStyle(
                fontWeight: _selectedIndex == i ? FontWeight.w600 : FontWeight.normal,
                color: _selectedIndex == i ? AppColors.primaryDark : AppColors.textPrimary,
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
                      backgroundColor: AppColors.primaryDark.withValues(alpha: 0.2),
                      child: Text(
                        (_user.prenom.isNotEmpty
                                ? _user.prenom[0]
                                : _user.email[0])
                            .toUpperCase(),
                        style: const TextStyle(color: AppColors.primaryDark),
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
