import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/user.dart';
import '../services/app_settings_service.dart';
import '../services/auth_service.dart';
import 'feed_page.dart';
import 'home_page.dart';
import 'creator_dashboard_page.dart';
import 'account_page.dart';
import 'settings_page.dart';
import 'new_post_page.dart';
import 'notifications_page.dart';
import '../services/notifications_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  UserRole _role = UserRole.patron;

  @override
  void initState() {
    super.initState();
    _loadRole();
    AppSettingsService.locale.addListener(_onLocaleChange);
    AuthService.roleNotifier.addListener(_onRoleChange);
  }

  @override
  void dispose() {
    AppSettingsService.locale.removeListener(_onLocaleChange);
    AuthService.roleNotifier.removeListener(_onRoleChange);
    super.dispose();
  }

  void _onLocaleChange() => setState(() {});

  void _onRoleChange() {
    final roleStr = AuthService.roleNotifier.value;
    if (roleStr != null && mounted) {
      setState(() {
        switch (roleStr) {
          case 'creator':
            _role = UserRole.creator;
          case 'both':
            _role = UserRole.both;
          default:
            _role = UserRole.patron;
        }
      });
    }
  }

  Future<void> _loadRole() async {
    final roleStr = await AuthService.getRole();
    if (!mounted) return;
    setState(() {
      switch (roleStr) {
        case 'creator':
          _role = UserRole.creator;
        case 'both':
          _role = UserRole.both;
        default:
          _role = UserRole.patron;
      }
    });
  }

  bool get _isCreator => _role == UserRole.creator || _role == UserRole.both;

  List<Widget> get _pages => _isCreator
      ? [
          const FeedPage(),
          const HomePage(),
          const CreatorDashboardPage(),
          const AccountPage(),
          const SettingsPage(),
        ]
      : [
          const FeedPage(),
          const HomePage(),
          const AccountPage(),
          const SettingsPage(),
        ];

  List<NavigationDestination> get _destinations {
    if (_isCreator) {
      return [
        NavigationDestination(
          icon: const Icon(Icons.rss_feed_outlined),
          selectedIcon: const Icon(Icons.rss_feed),
          label: L10n.t('feed'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.explore_outlined),
          selectedIcon: const Icon(Icons.explore),
          label: L10n.t('authors'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: L10n.t('dashboard'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: L10n.t('account'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: L10n.t('settings'),
        ),
      ];
    }
    return [
      NavigationDestination(
        icon: const Icon(Icons.rss_feed_outlined),
        selectedIcon: const Icon(Icons.rss_feed),
        label: L10n.t('feed'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.explore_outlined),
        selectedIcon: const Icon(Icons.explore),
        label: L10n.t('authors'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: L10n.t('account'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: L10n.t('settings'),
      ),
    ];
  }

  bool get _showFab {
    if (!_isCreator) return false;
    return _index == 0 || _index == 2;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final safeIndex = _index.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: pages,
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const NewPostPage()),
                );
                if (created == true && mounted) setState(() {});
              },
              tooltip: L10n.t('new_post'),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final count = await NotificationsService.unreadCount();
      if (mounted) setState(() => _unread = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text('$_unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
      tooltip: 'Notifications',
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        );
        _loadCount();
      },
    );
  }
}
