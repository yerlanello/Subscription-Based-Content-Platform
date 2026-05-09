import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    AppSettingsService.locale.addListener(_onChange);
    AppSettingsService.themeMode.addListener(_onChange);
  }

  @override
  void dispose() {
    AppSettingsService.locale.removeListener(_onChange);
    AppSettingsService.themeMode.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  Future<void> _logout(BuildContext context) async {
    await AuthService.clearTokens();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode_outlined),
              title: Text(L10n.t('light')),
              trailing: AppSettingsService.themeMode.value == ThemeMode.light
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                AppSettingsService.setTheme(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text(L10n.t('dark')),
              trailing: AppSettingsService.themeMode.value == ThemeMode.dark
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                AppSettingsService.setTheme(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_auto_outlined),
              title: Text(L10n.t('system')),
              trailing: AppSettingsService.themeMode.value == ThemeMode.system
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                AppSettingsService.setTheme(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LangTile(code: 'en', label: 'English', ctx: ctx),
            _LangTile(code: 'ru', label: 'Русский', ctx: ctx),
            _LangTile(code: 'kk', label: 'Қазақша', ctx: ctx),
          ],
        ),
      ),
    );
  }

  String get _themeLabel {
    switch (AppSettingsService.themeMode.value) {
      case ThemeMode.light:
        return L10n.t('light');
      case ThemeMode.dark:
        return L10n.t('dark');
      default:
        return L10n.t('system');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('settings'))),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _SectionLabel(label: L10n.t('preferences')),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(L10n.t('appearance')),
                  subtitle: Text(_themeLabel,
                      style: TextStyle(color: colorScheme.outline)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showThemePicker,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(L10n.t('language')),
                  subtitle: Text(L10n.currentLanguageLabel,
                      style: TextStyle(color: colorScheme.outline)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showLanguagePicker,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(label: L10n.t('privacy_security')),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(L10n.t('change_password')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(L10n.t('privacy_policy')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(L10n.t('terms_of_service')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(label: L10n.t('about')),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(L10n.t('app_version')),
                  trailing: Text('0.1.0', style: TextStyle(color: colorScheme.outline)),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(L10n.t('help_support')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: Text(L10n.t('log_out'),
                  style: const TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  const _LangTile({required this.code, required this.label, required this.ctx});
  final String code;
  final String label;
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) {
    final selected = AppSettingsService.locale.value == code;
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () {
        AppSettingsService.setLocale(code);
        Navigator.pop(ctx);
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
