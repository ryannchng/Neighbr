import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../models/business_model.dart';
import '../../models/category_model.dart';
import '../../repositories/business_repository.dart';

// ============================================================================
// Enums
// ============================================================================

enum SortOption {
  topRated('Top Rated', Icons.star_rounded),
  newest('Newest', Icons.schedule_rounded),
  mostReviewed('Most Reviewed', Icons.reviews_rounded),
  nameAZ('Name A–Z', Icons.sort_by_alpha_rounded);

  const SortOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

// ============================================================================
// Screen
// ============================================================================

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _repo = BusinessRepository();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // Data
  List<Category> _categories = [];
  List<Business> _businesses = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  // Filters
  Set<String> _activeCategoryIds = <String>{};
  SortOption _sort = SortOption.topRated;
  String _searchQuery = '';
  int _offset = 0;

  // Search debounce
  Timer? _searchDebounce;
  bool _isSearching = false;
  bool _searchActive = false;
  List<Business> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Pagination / Scroll ────────────────────────────────────────────────────

  void _onScroll() {
    if (_searchActive) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _businesses = [];
      _hasMore = true;
    });
    try {
      final cats = await _repo.getCategories();
      final businesses = await _fetchPage(offset: 0);
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _businesses = businesses;
        _offset = businesses.length;
        _hasMore = businesses.length == AppConstants.pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load businesses. Pull down to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _searchActive || _activeCategoryIds.isNotEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _fetchPage(offset: _offset);
      if (!mounted) return;
      setState(() {
        _businesses.addAll(more);
        _offset += more.length;
        _hasMore = more.length == AppConstants.pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<List<Business>> _fetchPage({required int offset}) async {
    if (_activeCategoryIds.isNotEmpty) {
      if (offset > 0) return [];
      final grouped = await Future.wait(
        _activeCategoryIds.map(
          (id) => _repo.getByCategory(
            id,
            sort: _sort,
            limit: AppConstants.pageSize,
            offset: 0,
          ),
        ),
      );

      final byId = <String, Business>{};
      for (final list in grouped) {
        for (final business in list) {
          byId[business.id] = business;
        }
      }
      return byId.values.toList();
    }

    return _repo.getAll(
      sort: _sort,
      limit: AppConstants.pageSize,
      offset: offset,
    );
  }

  Future<void> _applyFilter({
    String? categoryToggleId,
    SortOption? sort,
  }) async {
    setState(() {
      if (categoryToggleId != null) {
        if (_activeCategoryIds.contains(categoryToggleId)) {
          _activeCategoryIds.remove(categoryToggleId);
        } else {
          _activeCategoryIds.add(categoryToggleId);
        }
      }
      if (sort != null) _sort = sort;
      _offset = 0;
      _businesses = [];
      _hasMore = true;
      _loading = true;
    });
    try {
      final businesses = await _fetchPage(offset: 0);
      if (!mounted) return;
      setState(() {
        _businesses = businesses;
        _offset = businesses.length;
        _hasMore = _activeCategoryIds.isEmpty &&
            businesses.length == AppConstants.pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load businesses.';
        _loading = false;
      });
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    final q = value.trim();
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = q;
      _isSearching = q.isNotEmpty;
    });
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _repo.search(q);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _isSearching = false);
      }
    });
  }

  void _activateSearch() => setState(() => _searchActive = true);

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchActive = false;
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
    });
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openBusiness(String id) => context.push('/businesses/$id');

  // ── Sort sheet ─────────────────────────────────────────────────────────────

  void _showSortSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outline.withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Sort by',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ...SortOption.values.map((opt) => ListTile(
                    leading: Icon(opt.icon,
                        color: _sort == opt
                            ? colorScheme.primary
                            : colorScheme.onSurface.withAlpha(153)),
                    title: Text(
                      opt.label,
                      style: TextStyle(
                        fontWeight: _sort == opt
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: _sort == opt
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    trailing: _sort == opt
                        ? Icon(Icons.check_rounded, color: colorScheme.primary)
                        : null,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (_sort != opt) _applyFilter(sort: opt);
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadInitial,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildTopBar(colorScheme),
              if (!_searchActive) _buildFilterRow(colorScheme),

              // ── Search active ──────────────────────────────────────────────
              if (_searchActive) ...[
                _buildSearchContent(),

              // ── Normal browse ──────────────────────────────────────────────
              ] else if (_loading) ...[
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else if (_error != null) ...[
                SliverFillRemaining(
                  child: _ErrorView(
                      message: _error!, onRetry: _loadInitial),
                ),
              ] else ...[
                _buildResultsHeader(colorScheme),
                _buildBusinessList(),
                if (_loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (!_hasMore && _businesses.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '— End of results —',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colorScheme.onSurface.withAlpha(77),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(ColorScheme colorScheme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_searchActive)
              Text(
                'Browse',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            if (!_searchActive) const SizedBox(height: 16),
            // Search bar
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _searchActive
                  ? _ActiveSearchBar(
                      key: const ValueKey('active'),
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onClose: _clearSearch,
                    )
                  : _TapSearchBar(
                      key: const ValueKey('tap'),
                      onTap: _activateSearch,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter row ─────────────────────────────────────────────────────────────

  Widget _buildFilterRow(ColorScheme colorScheme) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length + 1, // +1 for "All" chip
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  // "All" chip
                  final selected = _activeCategoryIds.isEmpty;
                  return _FilterChip(
                    label: 'All',
                    icon: Icons.apps_rounded,
                    selected: selected,
                    onTap: () {
                      if (!selected) {
                        setState(() => _activeCategoryIds = <String>{});
                        _applyFilter();
                      }
                    },
                  );
                }
                final cat = _categories[i - 1];
                return _FilterChip(
                  label: cat.name,
                  icon: _categoryIconForName(cat.name),
                  selected: _activeCategoryIds.contains(cat.id),
                  onTap: () => _applyFilter(categoryToggleId: cat.id),
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // Sort button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                _SortButton(
                  label: _sort.label,
                  icon: _sort.icon,
                  onTap: _showSortSheet,
                ),
                const Spacer(),
                if (_activeCategoryIds.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _activeCategoryIds = <String>{});
                      _applyFilter();
                    },
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Clear filter'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          colorScheme.onSurface.withAlpha(153),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      textStyle: const TextStyle(fontSize: 13),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Results header ─────────────────────────────────────────────────────────

  Widget _buildResultsHeader(ColorScheme colorScheme) {
    String label = 'All Businesses';
    if (_activeCategoryIds.length == 1) {
      final selectedId = _activeCategoryIds.first;
      final cat = _categories.where((c) => c.id == selectedId).firstOrNull;
      if (cat != null) label = cat.name;
    } else if (_activeCategoryIds.length > 1) {
      label = '${_activeCategoryIds.length} Categories';
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            if (_businesses.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      colorScheme.surfaceContainerHighest.withAlpha(179),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_businesses.length}${_hasMore ? '+' : ''}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withAlpha(140),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Business list ──────────────────────────────────────────────────────────

  Widget _buildBusinessList() {
    if (_businesses.isEmpty) {
      return SliverFillRemaining(
        child: _EmptyState(
          message: _activeCategoryIds.isNotEmpty
              ? 'No businesses in this category yet.'
              : 'No businesses found.',
        ),
      );
    }

    return SliverList.separated(
      itemCount: _businesses.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 20,
        endIndent: 20,
      ),
      itemBuilder: (context, i) => _BusinessTile(
        business: _businesses[i],
        onTap: () => _openBusiness(_businesses[i].id),
      ),
    );
  }

  // ── Search results sliver ──────────────────────────────────────────────────

  Widget _buildSearchContent() {
    if (_isSearching) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_searchQuery.isEmpty) {
      return const SliverFillRemaining(
        child: _EmptyState(
          icon: Icons.search_rounded,
          message: 'Start typing to search businesses…',
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return SliverFillRemaining(
        child: _EmptyState(
          icon: Icons.search_off_rounded,
          message: 'No results for "$_searchQuery".',
        ),
      );
    }

    return SliverList.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 20, endIndent: 20),
      itemBuilder: (context, i) => _BusinessTile(
        business: _searchResults[i],
        onTap: () => _openBusiness(_searchResults[i].id),
        highlight: _searchQuery,
      ),
    );
  }
}

// ============================================================================
// Search bar widgets
// ============================================================================

class _TapSearchBar extends StatelessWidget {
  const _TapSearchBar({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(153),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withAlpha(51)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                size: 20, color: colorScheme.onSurface.withAlpha(102)),
            const SizedBox(width: 10),
            Text(
              'Search by name, city, keyword…',
              style: TextStyle(
                fontSize: 14.5,
                color: colorScheme.onSurface.withAlpha(102),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSearchBar extends StatefulWidget {
  const _ActiveSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  State<_ActiveSearchBar> createState() => _ActiveSearchBarState();
}

class _ActiveSearchBarState extends State<_ActiveSearchBar> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(153),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withAlpha(102)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              size: 20, color: colorScheme.primary.withAlpha(179)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search by name, city, keyword…',
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14.5),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Cancel search',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Filter chip
// ============================================================================

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 15,
          color: selected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface.withAlpha(166),
        ),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 12.5,
          ),
        ),
        onSelected: (_) => onTap(),
        backgroundColor:
            colorScheme.surfaceContainerHighest.withAlpha(128),
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: selected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface,
        ),
        side: BorderSide(
          color: selected
              ? colorScheme.primary.withAlpha(102)
              : colorScheme.outline.withAlpha(51),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

IconData _categoryIconForName(String name) {
  final n = name.toLowerCase();
  if (n.contains('food') || n.contains('dining') || n.contains('restaurant')) {
    return Icons.restaurant_rounded;
  }
  if (n.contains('retail') || n.contains('shop') || n.contains('store')) {
    return Icons.shopping_bag_rounded;
  }
  if (n.contains('service') || n.contains('repair')) {
    return Icons.handyman_rounded;
  }
  if (n.contains('health') || n.contains('wellness') || n.contains('medical')) {
    return Icons.favorite_rounded;
  }
  if (n.contains('entertainment') || n.contains('event')) {
    return Icons.theaters_rounded;
  }
  if (n.contains('beauty') || n.contains('salon') || n.contains('barber')) {
    return Icons.content_cut_rounded;
  }
  return Icons.storefront_rounded;
}

// ============================================================================
// Sort button
// ============================================================================

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(128),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: colorScheme.outline.withAlpha(51)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withAlpha(179),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded,
                size: 16, color: colorScheme.onSurface.withAlpha(128)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Business tile
// ============================================================================

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({
    required this.business,
    required this.onTap,
    this.highlight,
  });
  final Business business;
  final VoidCallback onTap;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: _Thumbnail(imageUrl: business.primaryImage),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + verified
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          business.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (business.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified_rounded,
                            size: 15, color: colorScheme.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Category + price
                  Row(
                    children: [
                      if (business.category != null)
                        Flexible(
                          child: Text(
                            '${business.category!.icon} ${business.category!.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                        ),
                      if (business.priceRangeLabel != null) ...[
                        Text(
                          '  ·  ',
                          style: TextStyle(
                              color: colorScheme.onSurface.withAlpha(77)),
                        ),
                        Text(
                          business.priceRangeLabel!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Rating + location
                  Row(
                    children: [
                      _StarRow(rating: business.avgRating, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        business.avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' (${business.reviewCount})',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withAlpha(115),
                        ),
                      ),
                    ],
                  ),

                  if (business.location != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12,
                            color: colorScheme.onSurface.withAlpha(102)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            business.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  colorScheme.onSurface.withAlpha(115),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withAlpha(77)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Shared mini-widgets
// ============================================================================

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (imageUrl != null) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(color: colorScheme.surfaceContainerHighest),
        errorBuilder: (_, __, ___) => _placeholder(colorScheme),
      );
    }
    return _placeholder(colorScheme);
  }

  Widget _placeholder(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.store_outlined,
              color: cs.onSurface.withAlpha(64), size: 26),
        ),
      );
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.size = 14});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return Icon(
          filled
              ? Icons.star_rounded
              : half
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
          size: size,
          color: const Color(0xFFFBBF24),
        );
      }),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    this.icon = Icons.storefront_outlined,
    required this.message,
  });
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurface.withAlpha(51)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withAlpha(115),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 48, color: colorScheme.onSurface.withAlpha(51)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withAlpha(140)),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
                onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

