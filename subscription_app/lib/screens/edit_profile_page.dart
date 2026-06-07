import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _bioController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final stats = await AuthService.getMe();
      if (mounted) {
        setState(() {
          _bioController.text = stats.bio ?? '';
          _avatarUrl = stats.avatarUrl;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await AuthService.updateProfile(bio: _bioController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.t('post_saved'))),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() { _uploadingAvatar = true; _error = null; });
    try {
      final res = await ApiClient.postMultipart('/users/me/avatar', File(picked.path), 'avatar');
      final url = (res['data'] as Map<String, dynamic>?)?['avatar_url'] as String?;
      await AuthService.saveAvatarUrl(url);
      if (mounted) setState(() => _avatarUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.t('edit_profile')),
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
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: colorScheme.primary,
                        backgroundImage: _avatarUrl != null ? NetworkImage(AppConfig.absoluteUrl(_avatarUrl!)) : null,
                        child: _avatarUrl == null
                            ? Icon(Icons.person, size: 48, color: colorScheme.onPrimary)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _uploadingAvatar
                            ? const CircleAvatar(
                                radius: 16,
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : CircleAvatar(
                                radius: 16,
                                backgroundColor: colorScheme.primaryContainer,
                                child: IconButton(
                                  iconSize: 16,
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.camera_alt),
                                  onPressed: _pickAvatar,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _bioController,
                  maxLines: 5,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: L10n.t('bio'),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
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
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(L10n.t('save')),
                ),
              ],
            ),
    );
  }
}
