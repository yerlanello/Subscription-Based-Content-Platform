import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/become_creator_dialog.dart';
import 'edit_profile_page.dart';
import 'new_post_page.dart';
import 'my_subscriptions_page.dart';
import 'notifications_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? _username;
  String? _email;
  String? _avatarUrl;
  UserRole _role = UserRole.patron;
  int _subscriptionsCount = 0;
  int _followingCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final username = await AuthService.getUsername();
      final email = await AuthService.getEmail();
      final roleStr = await AuthService.getRole();
      final cachedAvatar = await AuthService.getAvatarUrl();

      if (mounted) {
        setState(() {
          _username = username;
          _email = email;
          _role = _parseRole(roleStr);
          _avatarUrl = cachedAvatar;
          _loading = false;
        });
      }

      // Fetch live stats in background
      final stats = await AuthService.getMe();
      if (mounted) {
        setState(() {
          _subscriptionsCount = stats.subscriptionsCount;
          _followingCount = stats.followingCount;
          _avatarUrl = stats.avatarUrl;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  UserRole _parseRole(String? raw) {
    switch (raw) {
      case 'creator':
        return UserRole.creator;
      case 'both':
        return UserRole.both;
      default:
        return UserRole.patron;
    }
  }

  bool get _isCreator => _role == UserRole.creator || _role == UserRole.both;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.t('account')),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: L10n.t('notifications'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  // Profile header
                  Container(
                    color: colorScheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: colorScheme.primary,
                          backgroundImage:
                              _avatarUrl != null ? NetworkImage(AppConfig.absoluteUrl(_avatarUrl!)) : null,
                          child: _avatarUrl == null
                              ? Text(
                                  (_username ?? '?')[0].toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimary),
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _username ?? 'Unknown',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer.withAlpha(180),
                              ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _StatCard(label: L10n.t('subscriptions'), value: '$_subscriptionsCount'),
                        const SizedBox(width: 12),
                        _StatCard(label: L10n.t('following_count'), value: '$_followingCount'),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: L10n.t('role'),
                          value: _role == UserRole.both
                              ? 'Both'
                              : _role == UserRole.creator
                                  ? 'Creator'
                                  : 'Patron',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Creator section
                  if (_isCreator) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(L10n.t('creator'),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListTile(
                        leading: const Icon(Icons.add_box_outlined),
                        title: Text(L10n.t('new_post')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final created = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => const NewPostPage()),
                          );
                          if (created == true && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(L10n.t('post_saved'))),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Profile section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(L10n.t('profile'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(L10n.t('edit_profile')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final changed = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(builder: (_) => const EditProfilePage()),
                            );
                            if (changed == true) _load();
                          },
                        ),
                        if (!_isCreator) ...[
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading: const Icon(Icons.star_outline),
                            title: Text(L10n.t('become_creator')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              if (!mounted) return;
                              final success = await BecomeCreatorDialog.show(context);
                              if (!mounted) return;
                              if (success) {
                                await AuthService.saveRole('creator');
                                _load();
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(L10n.t('subscriptions').toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListTile(
                      leading: const Icon(Icons.subscriptions_outlined),
                      title: Text(L10n.t('my_subscriptions')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MySubscriptionsPage()),
                    ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
