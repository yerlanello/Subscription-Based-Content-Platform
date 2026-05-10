import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/creator.dart';
import '../services/app_settings_service.dart';
import '../services/creators_service.dart';
import 'creator_profile_page.dart';

const _categories = ['All', 'Music', 'Art', 'Podcasts', 'Gaming', 'Education', 'Other'];
const _limit = 50;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<CreatorWithProfile> _creators = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _selectedCategory = 'All';
  String _query = '';
  int _offset = 0;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    AppSettingsService.locale.addListener(_onLocaleChange);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    AppSettingsService.locale.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() => setState(() {});

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _offset = 0; _hasMore = true; _creators = []; });
    try {
      final creators = await CreatorsService.list(limit: _limit, offset: 0);
      if (mounted) {
        setState(() {
          _creators = creators;
          _offset = creators.length;
          _hasMore = creators.length == _limit;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading || _query.isNotEmpty || _selectedCategory != 'All') return;
    setState(() => _loadingMore = true);
    try {
      final more = await CreatorsService.list(limit: _limit, offset: _offset);
      if (mounted) {
        setState(() {
          _creators.addAll(more);
          _offset += more.length;
          _hasMore = more.length == _limit;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<CreatorWithProfile> get _filtered {
    return _creators.where((c) {
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
      appBar: AppBar(title: const Text('Xabarla'), centerTitle: false),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            color: colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.t('support_creators'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  L10n.t('exclusive_content'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withAlpha(180),
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: L10n.t('search_creators'),
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
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (context, i) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                return FilterChip(
                  label: Text(cat),
                  selected: cat == _selectedCategory,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          Expanded(child: _buildBody(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) return const Center(child: CircularProgressIndicator());

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
            FilledButton(onPressed: _load, child: Text(L10n.t('retry'))),
          ],
        ),
      );
    }

    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _creators.isEmpty ? L10n.t('no_creators_yet') : L10n.t('no_match_search'),
          style: TextStyle(color: colorScheme.outline),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: filtered.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == filtered.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _CreatorCard(
            creator: filtered[i],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreatorProfilePage(username: filtered[i].user.username),
              ),
            ),
          );
        },
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
            Container(
              height: 80,
              color: colorScheme.secondaryContainer,
              child: profile.coverUrl != null
                  ? Image.network(profile.coverUrl!, fit: BoxFit.cover, width: double.infinity)
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
                  Text(profile.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('@${creator.user.username}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.outline)),
                  if (profile.category != null) ...[
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(profile.category!, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  if (profile.description != null) ...[
                    const SizedBox(height: 4),
                    Text(profile.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    profile.priceLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: profile.isFree ? Colors.green : colorScheme.primary,
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
