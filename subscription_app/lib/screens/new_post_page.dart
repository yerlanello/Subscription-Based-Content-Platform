import 'package:flutter/material.dart';
import '../services/posts_service.dart';

/// Shown only for users with the creator role.
class NewPostPage extends StatefulWidget {
  const NewPostPage({super.key});

  @override
  State<NewPostPage> createState() => _NewPostPageState();
}

class _NewPostPageState extends State<NewPostPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isFree = false;
  bool _publishNow = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final post = await PostsService.create(
        title: title,
        content: _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        isFree: _isFree,
      );
      if (_publishNow) {
        await PostsService.publish(post.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _publishNow ? 'Post published!' : 'Draft saved.',
            ),
          ),
        );
        Navigator.of(context).pop(true); // signal success
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title field
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'What is this post about?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Content field
          TextField(
            controller: _contentController,
            maxLines: 10,
            minLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Content',
              hintText: 'Write something...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // Options
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Free post'),
                  subtitle: const Text('Visible to everyone, not just subscribers'),
                  value: _isFree,
                  onChanged: (v) => setState(() => _isFree = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Publish immediately'),
                  subtitle: const Text('Leave off to save as draft'),
                  value: _publishNow,
                  onChanged: (v) => setState(() => _publishNow = v),
                ),
              ],
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
              child: Text(
                _error!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: const Text('Save Post'),
          ),
        ],
      ),
    );
  }
}
