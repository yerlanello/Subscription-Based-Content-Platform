import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../services/posts_service.dart';

// Supported file extensions the backend accepts
const _imageExts = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
const _videoExts = {'mp4', 'webm', 'mov'};
const _audioExts = {'mp3', 'wav', 'ogg', 'm4a'};

bool _isImage(PlatformFile f) => _imageExts.contains(f.extension?.toLowerCase());
bool _isVideo(PlatformFile f) => _videoExts.contains(f.extension?.toLowerCase());
bool _isAudio(PlatformFile f) => _audioExts.contains(f.extension?.toLowerCase());

IconData _iconFor(PlatformFile f) {
  if (_isVideo(f)) return Icons.videocam_outlined;
  if (_isAudio(f)) return Icons.audiotrack_outlined;
  if (f.extension?.toLowerCase() == 'pdf') return Icons.picture_as_pdf_outlined;
  return Icons.insert_drive_file_outlined;
}

Widget _filePlaceholder(BuildContext context, PlatformFile f) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    width: 80, height: 80,
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(_iconFor(f), color: cs.primary, size: 28),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            f.name,
            style: TextStyle(fontSize: 9, color: cs.outline),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

class NewPostPage extends StatefulWidget {
  const NewPostPage({super.key});

  @override
  State<NewPostPage> createState() => _NewPostPageState();
}

class _NewPostPageState extends State<NewPostPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _videoUrlController = TextEditingController();
  bool _isFree = false;
  bool _publishNow = true;
  bool _submitting = false;
  bool _uploadingFiles = false;
  List<PlatformFile> _pickedFiles = [];
  String? _videoUrl;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _pickedFiles = [..._pickedFiles, ...result.files]);
  }

  void _removeFile(int index) => setState(() => _pickedFiles.removeAt(index));

  Future<void> _showVideoUrlDialog() async {
    _videoUrlController.text = _videoUrl ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Video URL'),
        content: TextField(
          controller: _videoUrlController,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://example.com/video.mp4',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final url = _videoUrlController.text.trim();
      setState(() => _videoUrl = url.isEmpty ? null : url);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = L10n.t('title_required'));
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final post = await PostsService.create(
        title: title,
        content: _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        isFree: _isFree,
      );

      if (_pickedFiles.isNotEmpty || _videoUrl != null) {
        setState(() => _uploadingFiles = true);

        for (final pf in _pickedFiles) {
          if (pf.path == null) continue;
          await ApiClient.postMultipart(
            '/posts/${post.id}/attachments',
            File(pf.path!),
            'file',
          );
        }

        if (_videoUrl != null && _videoUrl!.isNotEmpty) {
          await ApiClient.post(
            '/posts/${post.id}/attachments/url',
            body: {'url': _videoUrl!},
          );
        }

        setState(() => _uploadingFiles = false);
      }

      if (_publishNow) await PostsService.publish(post.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_publishNow ? L10n.t('post_published') : L10n.t('draft_saved'))),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _submitting = false; _uploadingFiles = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.t('new_post')),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(L10n.t('save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: L10n.t('title'),
              hintText: L10n.t('what_is_post_about'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 10,
            minLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: L10n.t('content'),
              hintText: L10n.t('write_something'),
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // Picked file previews
          if (_pickedFiles.isNotEmpty) ...[
            Text(
              '${_pickedFiles.length} file(s) selected',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pickedFiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = _pickedFiles[i];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _isImage(f) && f.path != null
                            ? Image.file(
                                File(f.path!),
                                width: 80, height: 80,
                                fit: BoxFit.cover,
                                cacheWidth: 240,
                                errorBuilder: (ctx, _, _) => _filePlaceholder(ctx, f),
                              )
                            : _filePlaceholder(context, f),
                      ),
                      // Remove button
                      Positioned(
                        top: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => _removeFile(i),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Video URL chip
          if (_videoUrl != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _videoUrl!,
                      style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _videoUrl = null),
                    child: Icon(Icons.close, size: 16, color: colorScheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(L10n.t('free_post')),
                  subtitle: Text(L10n.t('free_post_subtitle')),
                  value: _isFree,
                  onChanged: (v) => setState(() => _isFree = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(L10n.t('publish_immediately')),
                  subtitle: Text(L10n.t('publish_immediately_subtitle')),
                  value: _publishNow,
                  onChanged: (v) => setState(() => _publishNow = v),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.attach_file_outlined),
                  title: const Text('Add files'),
                  subtitle: const Text('Images, videos, audio, PDF, TXT'),
                  trailing: _pickedFiles.isEmpty
                      ? const Icon(Icons.chevron_right)
                      : Badge(
                          label: Text('${_pickedFiles.length}'),
                          child: const Icon(Icons.attach_file),
                        ),
                  onTap: _pickFiles,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Add video URL'),
                  subtitle: const Text('Link to a video file'),
                  trailing: _videoUrl == null
                      ? const Icon(Icons.chevron_right)
                      : Icon(Icons.check_circle, color: colorScheme.primary),
                  onTap: _showVideoUrlDialog,
                ),
              ],
            ),
          ),

          if (_uploadingFiles) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 4),
            const Text('Uploading files...', textAlign: TextAlign.center),
          ],

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
            onPressed: _submitting ? null : _submit,
            child: Text(L10n.t('save')),
          ),
        ],
      ),
    );
  }
}
