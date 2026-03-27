import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/become_creator_dialog.dart';
import 'new_post_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? _username;
  String? _email;
  UserRole _role = UserRole.patron;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final username = await AuthService.getUsername();
    final email = await AuthService.getEmail();
    final roleStr = await AuthService.getRole();
    if (mounted) {
      setState(() {
        _username = username;
        _email = email;
        _role = _parseRole(roleStr);
        _loading = false;
      });
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

  bool get _isCreator =>
      _role == UserRole.creator || _role == UserRole.both;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                        child: Text(
                          (_username ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                          ),
                        ),
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

                // Role badge + stats row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _StatCard(label: 'Subscriptions', value: '—'),
                      const SizedBox(width: 12),
                      _StatCard(label: 'Following', value: '—'),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Role',
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

                // Creator actions (only for creators)
                if (_isCreator) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'CREATOR',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.outline,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListTile(
                      leading: const Icon(Icons.add_box_outlined),
                      title: const Text('New Post'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final created = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) => const NewPostPage()),
                        );
                        if (created == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Post saved!')),
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
                  child: Text(
                    'PROFILE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                          letterSpacing: 1.2,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Edit Profile'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.photo_camera_outlined),
                        title: const Text('Change Avatar'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                      if (!_isCreator) ...[
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.star_outline),
                          title: const Text('Become a Creator'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final success =
                                await BecomeCreatorDialog.show(context);
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
                  child: Text(
                    'SUBSCRIPTIONS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                          letterSpacing: 1.2,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    leading: const Icon(Icons.subscriptions_outlined),
                    title: const Text('My Subscriptions'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ),

                const SizedBox(height: 32),
              ],
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
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
