import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../models/post.dart';
import '../services/api_client.dart';
import '../services/posts_service.dart';

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
  List<File> _newFiles = [];
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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _newFiles = picked.map((x) => File(x.path)).toList());
  }

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
        for (final file in _newFiles) {
          await ApiClient.postMultipart(
            '/posts/${widget.post.id}/attachments',
            file,
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
            ..._attachments.map((a) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.attach_file, size: 18),
                  title: Text(a.url.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 18),
                    onPressed: () => _deleteAttachment(a),
                  ),
                )),
            const SizedBox(height: 8),
          ],

          // New files picked
          if (_newFiles.isNotEmpty) ...[
            Text('New files (${_newFiles.length})', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _newFiles.length,
                separatorBuilder: (context, i) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_newFiles[i], width: 80, height: 80, fit: BoxFit.cover),
                ),
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
                  title: Text(L10n.t('add_attachments')),
                  trailing: const Icon(Icons.chevron_right),
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
