import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../models/business_model.dart';
import '../../repositories/owner_repository.dart';

class OwnerBusinessDetailScreen extends StatefulWidget {
  const OwnerBusinessDetailScreen({super.key, required this.businessId});
  final String businessId;

  @override
  State<OwnerBusinessDetailScreen> createState() =>
      _OwnerBusinessDetailScreenState();
}

class _OwnerBusinessDetailScreenState
    extends State<OwnerBusinessDetailScreen>
    with SingleTickerProviderStateMixin {
  final _repo = OwnerRepository();

  Business? _business;
  List<ReviewSummary> _reviews = [];
  RatingDistribution? _distribution;
  bool _loading = true;
  String? _error;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getBusinessById(widget.businessId),
        _repo.getReviews(widget.businessId),
        _repo.getRatingDistribution(widget.businessId),
      ]);
      if (!mounted) return;
      setState(() {
        _business = results[0] as Business?;
        _reviews = results[1] as List<ReviewSummary>;
        _distribution = results[2] as RatingDistribution;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load business details.';
        _loading = false;
      });
    }
  }

  void _editBusiness() {
    context
        .push(AppRoutes.ownerBusinessForm,
            extra: _business)
        .then((_) => _load());
  }

  Future<void> _deleteBusiness() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete listing?'),
        content: const Text(
            'This will permanently delete your business listing and all associated data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteBusiness(widget.businessId);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete listing.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _business == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Business not found'),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
          ],
        )),
      );
    }

    final b = _business!;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(b, colorScheme, innerBoxIsScrolled),
          SliverToBoxAdapter(child: _buildAnalyticsSummary(b, colorScheme)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Analytics'),
                  Tab(text: 'Reviews'),
                  Tab(text: 'Details'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _AnalyticsTab(business: b, distribution: _distribution),
            _ReviewsTab(reviews: _reviews),
            _DetailsTab(business: b),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
      Business b, ColorScheme colorScheme, bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      forceElevated: innerBoxIsScrolled,
      title: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded),
          tooltip: 'Edit listing',
          onPressed: _editBusiness,
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'delete') _deleteBusiness();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_rounded,
                      size: 18, color: colorScheme.error),
                  const SizedBox(width: 10),
                  Text('Delete listing',
                      style: TextStyle(color: colorScheme.error)),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: b.primaryImage != null
            ? Image.network(b.primaryImage!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.store_outlined,
                        size: 48, color: colorScheme.onSurface.withAlpha(64))))
            : Container(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(Icons.store_outlined,
                    size: 48, color: colorScheme.onSurface.withAlpha(64))),
      ),
    );
  }

  Widget _buildAnalyticsSummary(Business b, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _MiniStatCard(
            icon: Icons.star_rounded,
            value: b.avgRating.toStringAsFixed(1),
            label: 'Avg Rating',
            color: const Color(0xFFFBBF24),
          ),
          const SizedBox(width: 10),
          _MiniStatCard(
            icon: Icons.reviews_rounded,
            value: '${b.reviewCount}',
            label: 'Reviews',
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          _MiniStatCard(
            icon: b.isVerified
                ? Icons.verified_rounded
                : Icons.pending_rounded,
            value: b.isVerified ? 'Verified' : 'Pending',
            label: 'Status',
            color: b.isVerified ? Colors.green : colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Analytics Tab
// ============================================================================

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({
    required this.business,
    required this.distribution,
  });

  final Business business;
  final RatingDistribution? distribution;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dist = distribution;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Rating breakdown
        _SectionCard(
          title: 'Rating Breakdown',
          child: dist == null || dist.total == 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No reviews yet',
                        style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(128))),
                  ),
                )
              : Column(
                  children: List.generate(5, (i) {
                    final star = 5 - i;
                    final count = dist.counts[star - 1];
                    final pct =
                        dist.total > 0 ? count / dist.total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Row(
                              children: [
                                Text('$star',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 3),
                                const Icon(Icons.star_rounded,
                                    size: 13,
                                    color: Color(0xFFFBBF24)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: colorScheme
                                    .surfaceContainerHighest,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        const Color(0xFFFBBF24)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colorScheme.onSurface.withAlpha(140),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ),
        const SizedBox(height: 16),

        // Business performance highlights
        _SectionCard(
          title: 'Performance',
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.star_half_rounded,
                label: 'Average rating',
                value: '${business.avgRating.toStringAsFixed(2)} / 5.00',
              ),
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.reviews_outlined,
                label: 'Total reviews',
                value: '${business.reviewCount}',
              ),
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.calendar_today_rounded,
                label: 'Listed since',
                value: _formatDate(business.createdAt),
              ),
              const Divider(height: 20),
              _InfoRow(
                icon: business.isVerified
                    ? Icons.verified_rounded
                    : Icons.pending_rounded,
                label: 'Verification',
                value: business.isVerified ? 'Verified business' : 'Not verified',
                valueColor: business.isVerified
                    ? Colors.green
                    : colorScheme.tertiary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick tips card
        _SectionCard(
          title: '💡 Tips to grow your listing',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TipItem(
                text: business.primaryImage == null
                    ? 'Add photos to attract more customers.'
                    : 'Add more photos to showcase your business.',
              ),
              _TipItem(
                text: business.reviewCount < 5
                    ? 'Ask your regular customers to leave a review.'
                    : 'Keep responding to reviews to build trust.',
              ),
              _TipItem(
                text: business.description.length < 100
                    ? 'Write a detailed description (100+ words).'
                    : 'Keep your business hours up to date.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ============================================================================
// Reviews Tab
// ============================================================================

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.reviews});
  final List<ReviewSummary> reviews;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rate_review_outlined,
                size: 48, color: colorScheme.onSurface.withAlpha(51)),
            const SizedBox(height: 12),
            Text(
              'No reviews yet',
              style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface.withAlpha(128)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _ReviewCard(review: reviews[i]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final ReviewSummary review;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withAlpha(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  review.authorUsername[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorUsername,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colorScheme.onSurface.withAlpha(115),
                      ),
                    ),
                  ],
                ),
              ),
              // Stars
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 15,
                    color: const Color(0xFFFBBF24),
                  ),
                ),
              ),
            ],
          ),

          // Review content
          if (review.content != null && review.content!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.content!,
              style: TextStyle(
                fontSize: 13.5,
                color: colorScheme.onSurface.withAlpha(204),
                height: 1.5,
              ),
            ),
          ],

          // Badges
          if (review.isVerifiedVisit || review.isFlagged) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                if (review.isVerifiedVisit)
                  _Badge(
                    label: 'Verified visit',
                    color: Colors.green,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                if (review.isFlagged)
                  _Badge(
                    label: 'Flagged',
                    color: colorScheme.error,
                    icon: Icons.flag_outlined,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ============================================================================
// Details Tab
// ============================================================================

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.business});
  final Business business;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: 'Basic Info',
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.store_rounded,
                label: 'Name',
                value: business.name,
              ),
              if (business.category != null) ...[
                const Divider(height: 20),
                _InfoRow(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  value:
                      '${business.category!.icon} ${business.category!.name}',
                ),
              ],
              if (business.description.isNotEmpty) ...[
                const Divider(height: 20),
                _InfoRow(
                  icon: Icons.description_rounded,
                  label: 'Description',
                  value: business.description,
                ),
              ],
              if (business.priceRangeLabel != null) ...[
                const Divider(height: 20),
                _InfoRow(
                  icon: Icons.attach_money_rounded,
                  label: 'Price range',
                  value: business.priceRangeLabel!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        _SectionCard(
          title: 'Location & Contact',
          child: Column(
            children: [
              if (business.address != null) ...[
                _InfoRow(
                  icon: Icons.location_on_rounded,
                  label: 'Address',
                  value: business.address!,
                ),
                const Divider(height: 20),
              ],
              if (business.location != null) ...[
                _InfoRow(
                  icon: Icons.map_rounded,
                  label: 'City / Province',
                  value: business.location!,
                ),
                const Divider(height: 20),
              ],
              if (business.phone != null) ...[
                _InfoRow(
                  icon: Icons.phone_rounded,
                  label: 'Phone',
                  value: business.phone!,
                ),
                const Divider(height: 20),
              ],
              if (business.website != null)
                _InfoRow(
                  icon: Icons.language_rounded,
                  label: 'Website',
                  value: business.website!,
                  valueColor: colorScheme.primary,
                )
              else
                _InfoRow(
                  icon: Icons.language_rounded,
                  label: 'Website',
                  value: 'Not set',
                  valueColor: colorScheme.onSurface.withAlpha(102),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ============================================================================
// Shared sub-widgets
// ============================================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withAlpha(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colorScheme.onSurface.withAlpha(115),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor ?? colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withAlpha(38)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10.5,
                  color: colorScheme.onSurface.withAlpha(115)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  const _TipItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right_rounded,
              size: 18, color: colorScheme.primary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: colorScheme.onSurface.withAlpha(204),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SliverPersistentHeader delegate for pinned tab bar
// ============================================================================

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}