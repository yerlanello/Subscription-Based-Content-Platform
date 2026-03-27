import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'feed_page.dart';
import 'home_page.dart';
import 'new_post_page.dart';
import 'account_page.dart';
import 'settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  UserRole _role = UserRole.patron;

  static const _pages = <Widget>[
    FeedPage(),
    HomePage(),
    AccountPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadRole();
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

  bool get _isCreator =>
      _role == UserRole.creator || _role == UserRole.both;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      floatingActionButton: _isCreator && _index == 0
          ? FloatingActionButton(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const NewPostPage()),
                );
                if (created == true && mounted) {
                  // Rebuild feed tab by forcing a key change if needed;
                  // for now a simple setState is enough to trigger feed refresh
                  setState(() {});
                }
              },
              tooltip: 'New Post',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.rss_feed_outlined),
            selectedIcon: Icon(Icons.rss_feed),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Authors',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
