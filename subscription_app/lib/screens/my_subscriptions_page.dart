import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../models/creator.dart';
import '../services/creators_service.dart';
import 'creator_profile_page.dart';

class MySubscriptionsPage extends StatefulWidget {
  const MySubscriptionsPage({super.key});

  @override
  State<MySubscriptionsPage> createState() => _MySubscriptionsPageState();
}

class _MySubscriptionsPageState extends State<MySubscriptionsPage> {
  List<CreatorWithProfile>? _subscriptions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subs = await CreatorsService.getMySubscriptions();
      if (mounted) setState(() => _subscriptions = subs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('my_subscriptions'))),
      body: Builder(builder: (_) {
        if (_loading) return const Center(child: CircularProgressIndicator());

        if (_error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error!),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: Text(L10n.t('retry'))),
              ],
            ),
          );
        }

        if (_subscriptions == null || _subscriptions!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.subscriptions_outlined,
                    size: 56, color: colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text(L10n.t('no_subscriptions'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(L10n.t('no_subscriptions_subtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colorScheme.outline, fontSize: 13)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _subscriptions!.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) {
              final c = _subscriptions![i];
              return ListTile(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      CreatorProfilePage(username: c.user.username),
                )),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primary,
                  backgroundImage: c.user.avatarUrl != null
                      ? NetworkImage(AppConfig.absoluteUrl(c.user.avatarUrl!))
                      : null,
                  child: c.user.avatarUrl == null
                      ? Text(
                          c.profile.displayName[0].toUpperCase(),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary),
                        )
                      : null,
                ),
                title: Text(c.profile.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('@${c.user.username}',
                    style: TextStyle(color: colorScheme.outline)),
                trailing: c.profile.isFree
                    ? null
                    : Text(
                        c.profile.priceLabel,
                        style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500),
                      ),
              );
            },
          ),
        );
      }),
    );
  }
}
