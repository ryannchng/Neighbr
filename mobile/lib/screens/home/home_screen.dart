import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/category_icon_mapper.dart';
import '../../core/router.dart';
import '../../core/supabase_client.dart';
import '../../models/business_model.dart';
import '../../repositories/business_repository.dart';

// ============================================================================
// Data bundle loaded in one shot
// ============================================================================
class _HomeData {
  const _HomeData({required this.featured, required this.newest});

  final List<Business> featured;
  final List<Business> newest;
}

// ============================================================================
// Screen
// ============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = BusinessRepository();

  _HomeData? _data;
  bool _loading = true;
  String? _error;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Data loading
  // -------------------------------------------------------------------------

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getFeatured(),
        _repo.getNewest(),
      ]);
      if (!mounted) return;
      setState(() {
        _data = _HomeData(featured: results[0], newest: results[1]);
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

  // -------------------------------------------------------------------------
  // Navigation helpers
  // -------------------------------------------------------------------------

  void _goToBusiness(String id) => context.push('/businesses/$id');

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(colorScheme),
              if (_loading) ...[
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else if (_error != null) ...[
                SliverFillRemaining(
                  child: _ErrorView(message: _error!, onRetry: _load),
                ),
              ] else ...[
                if (_data!.featured.isNotEmpty) ...[
                  _buildSectionHeader('Featured'),
                  _buildFeaturedCarousel(),
                ],
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: GestureDetector(
                      onTap: () => context.push(AppRoutes.marketplaceNew),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withAlpha(204),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Can\'t find what you need?',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Post a request — local businesses will reach out.',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary.withAlpha(
                                        204,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.onPrimary.withAlpha(38),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Post',
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_data!.newest.isNotEmpty) ...[
                  _buildSectionHeader('Recently Added'),
                  _buildVerticalBusinessList(_data!.newest),
                ],
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // App bar
  // -------------------------------------------------------------------------

  Widget _buildAppBar(ColorScheme colorScheme) {
    final username =
        SupabaseClientProvider.currentUser?.email?.split('@').first ?? 'there';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: greeting + avatar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withAlpha(128),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Discover local gems',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                _AvatarButton(
                  username: username,
                  onTap: () => context.go(AppRoutes.profile),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  // -------------------------------------------------------------------------
  // Section header
  // -------------------------------------------------------------------------

  Widget _buildSectionHeader(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    ),
  );

  // -------------------------------------------------------------------------
  // Featured horizontal carousel
  // -------------------------------------------------------------------------

  Widget _buildFeaturedCarousel() => SliverToBoxAdapter(
    child: SizedBox(
      height: 220,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _data!.featured.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) => _FeaturedCard(
          business: _data!.featured[i],
          onTap: () => _goToBusiness(_data!.featured[i].id),
        ),
      ),
    ),
  );

  // -------------------------------------------------------------------------
  // Vertical list (newest / category results)
  // -------------------------------------------------------------------------

  Widget _buildVerticalBusinessList(List<Business> businesses) {
    if (businesses.isEmpty) {
      return const SliverToBoxAdapter(
        child: _EmptyState(message: 'No businesses found.'),
      );
    }
    return SliverList.separated(
      itemCount: businesses.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 20, endIndent: 20),
      itemBuilder: (context, i) => _BusinessListTile(
        business: businesses[i],
        onTap: () => _goToBusiness(businesses[i].id),
      ),
    );
  }
}

// ============================================================================
// Sub-widgets
// ============================================================================

// ---- Avatar button ---------------------------------------------------------

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.username, required this.onTap});

  final String username;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

// ---- Featured card (horizontal carousel) -----------------------------------

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.business, required this.onTap});

  final Business business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.surfaceContainerLow,
          border: Border.all(color: colorScheme.outline.withAlpha(38)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BusinessImage(imageUrl: business.primaryImage),
                  // Gradient scrim at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(140),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Rating badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _RatingBadge(rating: business.avgRating),
                  ),
                  // Verified badge
                  if (business.isVerified)
                    Positioned(top: 8, left: 8, child: _VerifiedBadge()),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (business.category != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CategoryIconMapper.fromKey(
                                business.category!.iconKey,
                                fallbackName: business.category!.name,
                              ),
                              size: 13,
                              color: colorScheme.onSurface.withAlpha(140),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              business.category!.name,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colorScheme.onSurface.withAlpha(140),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (business.priceRangeLabel != null) ...[
                        const Spacer(),
                        Text(
                          business.priceRangeLabel!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
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

// ---- Business list tile (vertical list) ------------------------------------

class _BusinessListTile extends StatelessWidget {
  const _BusinessListTile({required this.business, required this.onTap});

  final Business business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 68,
                height: 68,
                child: _BusinessImage(imageUrl: business.primaryImage),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (business.category != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CategoryIconMapper.fromKey(
                                business.category!.iconKey,
                                fallbackName: business.category!.name,
                              ),
                              size: 14,
                              color: colorScheme.onSurface.withAlpha(140),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              business.category!.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colorScheme.onSurface.withAlpha(140),
                              ),
                            ),
                          ],
                        ),
                      if (business.priceRangeLabel != null) ...[
                        Text(
                          '  ·  ',
                          style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(77),
                          ),
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
                      if (business.location != null) ...[
                        Text(
                          '  ·  ',
                          style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(77),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            business.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withAlpha(115),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurface.withAlpha(77),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Shared image widget ---------------------------------------------------

class _BusinessImage extends StatelessWidget {
  const _BusinessImage({this.imageUrl});

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
        errorBuilder: (_, _, _) => _placeholder(colorScheme),
      );
    }
    return _placeholder(colorScheme);
  }

  Widget _placeholder(ColorScheme colorScheme) => Container(
    color: colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        Icons.store_outlined,
        color: colorScheme.onSurface.withAlpha(64),
        size: 28,
      ),
    ),
  );
}

// ---- Rating badge (on cards) -----------------------------------------------

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(166),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFBBF24)),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Verified badge --------------------------------------------------------

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(166),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 11, color: Color(0xFF60A5FA)),
          SizedBox(width: 3),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Star row --------------------------------------------------------------

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

// ---- Empty state -----------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 48,
              color: colorScheme.onSurface.withAlpha(51),
            ),
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

// ---- Error view ------------------------------------------------------------

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
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: colorScheme.onSurface.withAlpha(51),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withAlpha(140),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

