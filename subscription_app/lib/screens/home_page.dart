import 'package:flutter/material.dart';
import '../models/creator.dart';
import '../services/creators_service.dart';
import 'creator_profile_page.dart';

const _categories = [
  'All',
  'Music',
  'Art',
  'Podcasts',
  'Gaming',
  'Education',
  'Other',
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<CreatorWithProfile>? _creators;
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'All';
  String _query = '';

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
      final creators = await CreatorsService.list();
      if (mounted) setState(() => _creators = creators);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CreatorWithProfile> get _filtered {
    if (_creators == null) return [];
    return _creators!.where((c) {
      final matchCat = _selectedCategory == 'All' ||
          (c.profile.category ?? '') == _selectedCategory;
      final q = _query.toLowerCase();
      final matchQuery = q.isEmpty ||
          c.profile.displayName.toLowerCase().contains(q) ||
          c.user.username.toLowerCase().contains(q) ||
          (c.profile.description ?? '').toLowerCase().contains(q);
      return matchCat && matchQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xabarla'),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero banner + search
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            color: colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support your favourite creators',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subscribe and get exclusive content',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withAlpha(180),
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search creators...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ],
            ),
          ),

          // Category chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final selected = cat == _selectedCategory;
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),

          // Body
          Expanded(child: _buildBody(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _creators?.isEmpty == true
              ? 'No creators yet.'
              : 'No creators match your search.',
          style: TextStyle(color: colorScheme.outline),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, i) => _CreatorCard(
          creator: filtered[i],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CreatorProfilePage(username: filtered[i].user.username),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard({required this.creator, required this.onTap});
  final CreatorWithProfile creator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = creator.profile;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover / avatar area
            Container(
              height: 80,
              color: colorScheme.secondaryContainer,
              child: profile.coverUrl != null
                  ? Image.network(profile.coverUrl!,
                      fit: BoxFit.cover, width: double.infinity)
                  : Center(
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.primary,
                        backgroundImage: creator.user.avatarUrl != null
                            ? NetworkImage(creator.user.avatarUrl!)
                            : null,
                        child: creator.user.avatarUrl == null
                            ? Text(
                                profile.displayName[0].toUpperCase(),
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${creator.user.username}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colorScheme.outline),
                  ),
                  if (profile.category != null) ...[
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(profile.category!,
                          style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  if (profile.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      profile.description!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    profile.priceLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: profile.isFree
                          ? Colors.green
                          : colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
