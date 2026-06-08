import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

/// Lets the user change their profile picture (avatar).
/// The creator bio/description lives in the Creator Dashboard settings, so it
/// is intentionally not edited here.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool _loading = true;
  bool _uploadingAvatar = false;
  bool _changed = false;
  String? _avatarUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await AuthService.getMe();
      if (mounted) {
        setState(() {
          _avatarUrl = stats.avatarUrl;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
      if (mounted) setState(() { _avatarUrl = url; _changed = true; });
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
            onPressed: () => Navigator.of(context).pop(_changed),
            child: Text(L10n.t('save')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: colorScheme.primary,
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(AppConfig.absoluteUrl(_avatarUrl!))
                            : null,
                        child: _avatarUrl == null
                            ? Icon(Icons.person, size: 56, color: colorScheme.onPrimary)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _uploadingAvatar
                            ? const CircleAvatar(
                                radius: 18,
                                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : CircleAvatar(
                                radius: 18,
                                backgroundColor: colorScheme.primaryContainer,
                                child: IconButton(
                                  iconSize: 18,
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.camera_alt),
                                  onPressed: _pickAvatar,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(L10n.t('change_avatar')),
                    onPressed: _uploadingAvatar ? null : _pickAvatar,
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
              ],
            ),
    );
  }
}
