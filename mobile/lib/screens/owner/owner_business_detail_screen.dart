import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../models/business_model.dart';
import '../../repositories/business_request_repository.dart';
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
  final _requestRepo = BusinessRequestRepository();

  late TabController _tabController;

  Business? _business;
  List<ReviewSummary> _reviews = [];
  RatingDistribution _distribution = const RatingDistribution(counts: [0, 0, 0, 0, 0]);
  List<BusinessRequest> _requests = [];

  bool _loading = true;
  String? _error;

  final Set<String> _processingIds = {};

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
        _requestRepo.getRequestsForBusiness(widget.businessId),
      ]);

      if (!mounted) return;
      setState(() {
        _business = results[0] as Business?;
        _reviews = results[1] as List<ReviewSummary>;
        _distribution = results[2] as RatingDistribution;
        _requests = results[3] as List<BusinessRequest>;
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

  Future<void> _claimRequest(String requestId) async {
    setState(() => _processingIds.add(requestId));
    try {
      await _requestRepo.takeRequest(requestId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not claim request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(requestId));
    }
  }

  Future<void> _markDone(String requestId) async {
    setState(() => _processingIds.add(requestId));
    try {
      await _requestRepo.markDone(requestId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark as done: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(requestId));
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
                FilledButton.tonal(onPressed: _load, child: const Text('Try again')),
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

    final openCount = _requests.where((r) => r.isOpen).length;
    final claimedCount = _requests.where((r) => r.isClaimed).length;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(business.name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
              child: _RequestsTabLabel(
                openCount: openCount,
                claimedCount: claimedCount,
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
          _RequestsTab(
            requests: _requests,
            processingIds: _processingIds,
            onClaim: _claimRequest,
            onMarkDone: _markDone,
          ),
          _DetailsTab(business: business),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Requests tab label with badge
// ---------------------------------------------------------------------------

class _RequestsTabLabel extends StatelessWidget {
  const _RequestsTabLabel({
    required this.openCount,
    required this.claimedCount,
  });

  final int openCount;
  final int claimedCount;

  @override
  Widget build(BuildContext context) {
    final pending = openCount + claimedCount;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Requests'),
        if (pending > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$pending',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Requests tab
// ---------------------------------------------------------------------------

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.requests,
    required this.processingIds,
    required this.onClaim,
    required this.onMarkDone,
  });

  final List<BusinessRequest> requests;
  final Set<String> processingIds;
  final void Function(String) onClaim;
  final void Function(String) onMarkDone;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.campaign_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No requests yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'Requests from customers will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final open = requests.where((r) => r.isOpen).toList();
    final inProgress = requests.where((r) => r.isClaimed).toList();
    final done = requests.where((r) => r.isCompleted).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (open.isNotEmpty) ...[
          _SectionHeader(label: 'Open', count: open.length, color: Colors.orange),
          const SizedBox(height: 8),
          ...open.map((r) => _RequestCard(
                request: r,
                isProcessing: processingIds.contains(r.id),
                onClaim: () => onClaim(r.id),
                onMarkDone: null,
              )),
          const SizedBox(height: 20),
        ],
        if (inProgress.isNotEmpty) ...[
          _SectionHeader(label: 'In Progress', count: inProgress.length, color: Colors.blue),
          const SizedBox(height: 8),
          ...inProgress.map((r) => _RequestCard(
                request: r,
                isProcessing: processingIds.contains(r.id),
                onClaim: null,
                onMarkDone: () => onMarkDone(r.id),
              )),
          const SizedBox(height: 20),
        ],
        if (done.isNotEmpty) ...[
          _SectionHeader(label: 'Done', count: done.length, color: Colors.green),
          const SizedBox(height: 8),
          ...done.map((r) => _RequestCard(
                request: r,
                isProcessing: false,
                onClaim: null,
                onMarkDone: null,
              )),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isProcessing,
    required this.onClaim,
    required this.onMarkDone,
  });

  final BusinessRequest request;
  final bool isProcessing;
  final VoidCallback? onClaim;
  final VoidCallback? onMarkDone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat('MMM d, yyyy').format(request.createdAt.toLocal());

    final (chipColor, chipLabel, chipIcon) = switch (request.status) {
      'open' => (Colors.orange, 'Open', Icons.radio_button_unchecked),
      'claimed' => (Colors.blue, 'In Progress', Icons.timelapse_rounded),
      'completed' => (Colors.green, 'Done', Icons.check_circle_rounded),
      _ => (Colors.grey, request.status, Icons.help_outline),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withAlpha(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 15, color: colorScheme.onSurface.withAlpha(128)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  request.requesterUsername ?? 'Customer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chipColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: chipColor.withAlpha(77)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, size: 11, color: chipColor),
                    const SizedBox(width: 4),
                    Text(
                      chipLabel,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: chipColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            request.requestText,
            style: TextStyle(
                fontSize: 14, height: 1.4, color: colorScheme.onSurface.withAlpha(210)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _MetaChip(icon: Icons.calendar_today_outlined, label: dateStr),
              if (request.maxBudget != null)
                _MetaChip(
                  icon: Icons.attach_money_rounded,
                  label: 'Budget: \$${request.maxBudget!.toStringAsFixed(0)}',
                ),
              if (request.neededBy != null)
                _MetaChip(
                  icon: Icons.event_outlined,
                  label: 'By ${DateFormat('MMM d').format(request.neededBy!.toLocal())}',
                ),
            ],
          ),
          if (onClaim != null || onMarkDone != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (onClaim != null)
                  FilledButton.tonal(
                    onPressed: onClaim,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('Claim'),
                  )
                else if (onMarkDone != null)
                  FilledButton(
                    onPressed: onMarkDone,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Mark as done'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.onSurface.withAlpha(128)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withAlpha(153)),
            ),
          ),
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
              fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
        ),
        const SizedBox(height: 12),
        ...List.generate(5, (i) {
          final star = 5 - i;
          final count = distribution.counts[star - 1];
          final pct = distribution.total == 0 ? 0.0 : count / distribution.total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text('$star',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFFBBF24)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text(
                    '$count',
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurface.withAlpha(140)),
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
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withAlpha(128))),
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
          Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13, color: colorScheme.onSurface.withAlpha(160))),
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
      separatorBuilder: (_, __) => const Divider(height: 1),
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
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(190),
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
          const Text('Description',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(business.description,
              style: TextStyle(
                  fontSize: 14, height: 1.45, color: colorScheme.onSurface.withAlpha(200))),
          const SizedBox(height: 20),
        ],
        if (business.location != null)
          _DetailRow(icon: Icons.location_on_outlined, value: business.location!),
        if (business.phone != null)
          _DetailRow(icon: Icons.phone_outlined, value: business.phone!),
        if (business.website != null)
          _DetailRow(icon: Icons.language_outlined, value: business.website!),
        if (business.category != null)
          _DetailRow(icon: Icons.category_rounded, value: business.category!.name),
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
            child: Text(value,
                style: TextStyle(
                    fontSize: 14, color: colorScheme.onSurface.withAlpha(200))),
          ),
        ],
      ),
    );
  }
}
