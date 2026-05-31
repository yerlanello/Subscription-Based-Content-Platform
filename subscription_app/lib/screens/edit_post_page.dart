import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/post.dart';
import '../services/api_client.dart';
import '../services/posts_service.dart';

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

IconData _iconForAttachment(PostAttachment a) {
  final mime = a.mimeType ?? '';
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime.startsWith('video/')) return Icons.videocam_outlined;
  if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
  if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mime == 'text/plain') return Icons.text_snippet_outlined;
  return Icons.attach_file;
}

class EditPostPage extends StatefulWidget {
  const EditPostPage({super.key, required this.post});
  final Post post;

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late bool _isFree;
  late List<PostAttachment> _attachments;
  List<PlatformFile> _newFiles = [];
  bool _submitting = false;
  bool _uploadingFiles = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _contentController = TextEditingController(text: widget.post.content ?? '');
    _isFree = widget.post.isFree;
    _attachments = List.from(widget.post.attachments);
    _refreshAttachments();
  }

  // List endpoints (feed, byCreator) don't return attachments — refetch the
  // single post so existing attachments show up, matching the web frontend.
  Future<void> _refreshAttachments() async {
    try {
      final fresh = await PostsService.getById(widget.post.id);
      if (mounted) setState(() => _attachments = List.from(fresh.attachments));
    } catch (_) {
      // Keep what we had if the refetch fails.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _newFiles = [..._newFiles, ...result.files]);
  }

  void _removeNewFile(int index) => setState(() => _newFiles.removeAt(index));

  Future<void> _deleteAttachment(PostAttachment a) async {
    try {
      await ApiClient.delete('/posts/${widget.post.id}/attachments/${a.id}');
      if (mounted) setState(() => _attachments.remove(a));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
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
      await PostsService.update(
        widget.post.id,
        title: title,
        content: _contentController.text.trim().isEmpty ? null : _contentController.text.trim(),
        isFree: _isFree,
      );

      if (_newFiles.isNotEmpty) {
        setState(() => _uploadingFiles = true);
        for (final pf in _newFiles) {
          if (pf.path == null) continue;
          await ApiClient.postMultipart(
            '/posts/${widget.post.id}/attachments',
            File(pf.path!),
            'file',
          );
        }
        setState(() => _uploadingFiles = false);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.t('post_saved'))),
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
        title: Text(L10n.t('edit')),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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

          // Existing attachments
          if (_attachments.isNotEmpty) ...[
            Text('Attachments', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            ..._attachments.map(
              (a) => ListTile(
                dense: true,
                leading: Icon(_iconForAttachment(a), size: 18),
                title: Text(
                  a.url.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: a.mimeType != null ? Text(a.mimeType!, style: const TextStyle(fontSize: 11)) : null,
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 18),
                  onPressed: () => _deleteAttachment(a),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Newly picked files
          if (_newFiles.isNotEmpty) ...[
            Text('New files (${_newFiles.length})', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _newFiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = _newFiles[i];
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
                      Positioned(
                        top: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => _removeNewFile(i),
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
            const SizedBox(height: 8),
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
                ListTile(
                  leading: const Icon(Icons.attach_file_outlined),
                  title: const Text('Add files'),
                  subtitle: const Text('Images, videos, audio, PDF, TXT'),
                  trailing: _newFiles.isEmpty
                      ? const Icon(Icons.chevron_right)
                      : Badge(
                          label: Text('${_newFiles.length}'),
                          child: const Icon(Icons.attach_file),
                        ),
                  onTap: _pickFiles,
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
