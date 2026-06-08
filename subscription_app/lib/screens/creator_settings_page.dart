import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/creators_service.dart';

/// Editor for the creator (author) profile: banner cover, display name,
/// description, category, subscription price and benefits.
/// Mirrors the web `/dashboard/settings` page.
class CreatorSettingsPage extends StatefulWidget {
  const CreatorSettingsPage({super.key});

  @override
  State<CreatorSettingsPage> createState() => _CreatorSettingsPageState();
}

class _CreatorSettingsPageState extends State<CreatorSettingsPage> {
  // Canonical category values — kept identical to the web frontend so data
  // stays consistent across platforms. Labels are localized for display.
  static const _categoryValues = [
    'Музыка',
    'Искусство',
    'Подкасты',
    'Игры',
    'Образование',
    'Другое',
  ];

  final _displayNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _benefitsController = TextEditingController();

  String? _username;
  String? _category;
  String? _coverUrl;
  File? _coverPreview;

  bool _loading = true;
  bool _saving = false;
  bool _uploadingCover = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _benefitsController.dispose();
    super.dispose();
  }

  String _categoryLabel(String value) {
    switch (value) {
      case 'Музыка':
        return L10n.t('cat_music');
      case 'Искусство':
        return L10n.t('cat_art');
      case 'Подкасты':
        return L10n.t('cat_podcasts');
      case 'Игры':
        return L10n.t('cat_games');
      case 'Образование':
        return L10n.t('cat_education');
      case 'Другое':
        return L10n.t('cat_other');
      default:
        return value;
    }
  }

  Future<void> _load() async {
    try {
      final username = await AuthService.getUsername();
      if (username == null) throw 'Not logged in';
      final page = await CreatorsService.getCreatorPage(username);
      final profile = page.profile;
      if (!mounted) return;
      setState(() {
        _username = username;
        _displayNameController.text = profile.displayName;
        _descriptionController.text = profile.description ?? '';
        _benefitsController.text = profile.subscriptionDescription ?? '';
        _priceController.text = profile.subscriptionPriceCents.toString();
        _coverUrl = profile.coverUrl;
        _category = profile.category;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickCover() async {
    final username = _username;
    if (username == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _coverPreview = File(picked.path);
      _uploadingCover = true;
      _error = null;
    });
    try {
      final profile = await CreatorsService.uploadCover(username, File(picked.path));
      if (mounted) setState(() => _coverUrl = profile.coverUrl);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _coverPreview = null; });
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _save() async {
    final username = _username;
    if (username == null) return;
    setState(() { _saving = true; _error = null; });
    try {
      await CreatorsService.updateProfile(
        username,
        displayName: _displayNameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category ?? '',
        subscriptionPriceCents: int.tryParse(_priceController.text.trim()) ?? 0,
        subscriptionDescription: _benefitsController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.t('profile_saved'))),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Build the dropdown items, including the current category even if it's not
    // one of the canonical values (so we never silently drop existing data).
    final values = [..._categoryValues];
    if (_category != null && _category!.isNotEmpty && !values.contains(_category)) {
      values.add(_category!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.t('profile_settings')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(L10n.t('save')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Cover / banner
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _uploadingCover ? null : _pickCover,
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colorScheme.primary, colorScheme.tertiary],
                            ),
                          ),
                          child: _coverImage(colorScheme),
                        ),
                      ),
                      if (_uploadingCover)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black38,
                            child: Center(child: CircularProgressIndicator(color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  L10n.t('cover_banner_hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
                const SizedBox(height: 20),

                _Label(L10n.t('display_name')),
                TextField(
                  controller: _displayNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),

                _Label(L10n.t('about_me')),
                TextField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                _Label(L10n.t('category')),
                DropdownButtonFormField<String>(
                  initialValue: (_category != null && _category!.isNotEmpty) ? _category : null,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  hint: Text(L10n.t('choose_category')),
                  items: values
                      .map((v) => DropdownMenuItem(value: v, child: Text(_categoryLabel(v))))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 16),

                _Label(L10n.t('subscription_price')),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixText: '₸',
                    hintText: '0',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  L10n.t('subscription_price_hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
                const SizedBox(height: 16),

                _Label(L10n.t('subscription_benefits')),
                TextField(
                  controller: _benefitsController,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: TextStyle(color: colorScheme.onErrorContainer)),
                  ),
                ],

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(L10n.t('save')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        child: Text(L10n.t('cancel')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _coverImage(ColorScheme colorScheme) {
    if (_coverPreview != null) {
      return Image.file(_coverPreview!, fit: BoxFit.cover, width: double.infinity, height: 140);
    }
    if (_coverUrl != null && _coverUrl!.isNotEmpty) {
      return Image.network(
        AppConfig.absoluteUrl(_coverUrl!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 140,
        errorBuilder: (_, __, ___) => _coverPlaceholder(),
      );
    }
    return _coverPlaceholder();
  }

  Widget _coverPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 28),
          const SizedBox(height: 6),
          Text(
            L10n.t('upload_cover'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
