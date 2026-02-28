import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:neighbr/repositories/marketplace_request_repository.dart';
import 'package:neighbr/screens/marketplace/marketplace_recommendations_tab.dart';

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

class _OwnerBusinessDetailScreenState extends State<OwnerBusinessDetailScreen>
    with SingleTickerProviderStateMixin {
  final _repo = OwnerRepository();
  final _marketplaceRepo = MarketplaceRequestRepository();


  late TabController _tabController;

  Business? _business;
  List<ReviewSummary> _reviews = [];
  RatingDistribution _distribution = const RatingDistribution(
    counts: [0, 0, 0, 0, 0],
  );

  int _pendingMarketplaceCount = 0;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        _marketplaceRepo.getPendingRecommendationCount(widget.businessId),
      ]);

      if (!mounted) return;
      setState(() {
        _business = results[0] as Business?;
        _reviews = results[1] as List<ReviewSummary>;
        _distribution = results[2] as RatingDistribution;
        _pendingMarketplaceCount = results[3] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load business details: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Business')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final business = _business;
    if (business == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Business')),
        body: const Center(child: Text('Business not found.')),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          business.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context
                .push(AppRoutes.ownerBusinessForm, extra: business)
                .then((_) => _load()),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Analytics'),
            const Tab(text: 'Reviews'),
            Tab(
              child: MarketplaceTabLabel(
                pendingCount: _pendingMarketplaceCount,
              ),
            ),
            const Tab(text: 'Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AnalyticsTab(
            business: business,
            reviews: _reviews,
            distribution: _distribution,
          ),
          _ReviewsTab(reviews: _reviews),
          MarketplaceRecommendationsTab(businessId: widget.businessId),
          _DetailsTab(business: business),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Analytics tab
// ---------------------------------------------------------------------------

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({
    required this.business,
    required this.reviews,
    required this.distribution,
  });

  final Business business;
  final List<ReviewSummary> reviews;
  final RatingDistribution distribution;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalReviews = reviews.length;
    final avg = business.avgRating;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Avg Rating',
                value: avg.toStringAsFixed(1),
                icon: Icons.star_rounded,
                color: const Color(0xFFFBBF24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Total Reviews',
                value: '$totalReviews',
                icon: Icons.reviews_rounded,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Rating Breakdown',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(5, (i) {
          final star = 5 - i;
          final count = distribution.counts[star - 1];
          final pct = distribution.total == 0
              ? 0.0
              : count / distribution.total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  '$star',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFFBBF24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withAlpha(140),
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        _InfoTile(
          icon: Icons.verified_rounded,
          label: 'Verification',
          value: business.isVerified ? 'Verified' : 'Not verified',
          color: business.isVerified ? Colors.green : Colors.grey,
        ),
        const SizedBox(height: 8),
        _InfoTile(
          icon: Icons.calendar_month_rounded,
          label: 'Listed since',
          value: DateFormat('MMM d, yyyy').format(business.createdAt),
          color: colorScheme.primary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withAlpha(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withAlpha(128),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withAlpha(38)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withAlpha(160),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reviews tab
// ---------------------------------------------------------------------------

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.reviews});

  final List<ReviewSummary> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Center(
        child: Text('No reviews yet.', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final review = reviews[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    review.authorUsername,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(
                      5,
                      (j) => Icon(
                        j < review.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 14,
                        color: const Color(0xFFFBBF24),
                      ),
                    ),
                  ),
                ],
              ),
              if (review.content != null && review.content!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  review.content!,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(190),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d, yyyy').format(review.createdAt.toLocal()),
                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Details tab
// ---------------------------------------------------------------------------

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (business.description.trim().isNotEmpty) ...[
          const Text(
            'Description',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            business.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: colorScheme.onSurface.withAlpha(200),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (business.location != null)
          _DetailRow(
            icon: Icons.location_on_outlined,
            value: business.location!,
          ),
        if (business.phone != null)
          _DetailRow(icon: Icons.phone_outlined, value: business.phone!),
        if (business.website != null)
          _DetailRow(icon: Icons.language_outlined, value: business.website!),
        if (business.category != null)
          _DetailRow(
            icon: Icons.category_rounded,
            value: business.category!.name,
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withAlpha(200),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
