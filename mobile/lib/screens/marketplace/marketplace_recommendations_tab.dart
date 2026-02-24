import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/category_icon_mapper.dart';
import '../../repositories/marketplace_request_repository.dart';

/// Drop-in tab for OwnerBusinessDetailScreen.
///
/// Usage — add to the TabController and TabBarView in that screen:
///
///   TabBar tabs:
///     Tab(child: _MarketplaceTabLabel(pendingCount: _pendingCount))
///
///   TabBarView children:
///     MarketplaceRecommendationsTab(businessId: widget.businessId)
///
class MarketplaceRecommendationsTab extends StatefulWidget {
  const MarketplaceRecommendationsTab({
    super.key,
    required this.businessId,
  });

  final String businessId;

  @override
  State<MarketplaceRecommendationsTab> createState() =>
      _MarketplaceRecommendationsTabState();
}

class _MarketplaceRecommendationsTabState
    extends State<MarketplaceRecommendationsTab> {
  final _repo = MarketplaceRequestRepository();

  List<RecommendedRequest> _recs = [];
  bool _loading = true;
  String? _error;

  final Set<String> _processing = {};

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
      final recs =
          await _repo.getRecommendationsForBusiness(widget.businessId);
      if (!mounted) return;
      setState(() {
        _recs = recs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load recommendations.';
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(
    RecommendedRequest rec,
    String action,
  ) async {
    setState(() => _processing.add(rec.recommendationId));
    try {
      switch (action) {
        case 'claim':
          await _repo.claimRecommendation(rec.recommendationId);
        case 'decline':
          await _repo.declineRecommendation(rec.recommendationId);
        case 'view':
          await _repo.markViewed(rec.recommendationId);
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(rec.recommendationId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                  onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    if (_recs.isEmpty) {
      return const _EmptyState();
    }

    // Separate by recommendation status
    final pending =
        _recs.where((r) => r.recommendationStatus == 'pending').toList();
    final viewed =
        _recs.where((r) => r.recommendationStatus == 'viewed').toList();
    final claimed =
        _recs.where((r) => r.recommendationStatus == 'claimed').toList();
    final declined =
        _recs.where((r) => r.recommendationStatus == 'declined').toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (pending.isNotEmpty) ...[
            _SectionHeader(
              label: 'New',
              count: pending.length,
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            ...pending.map((r) => _RecommendationCard(
                  rec: r,
                  isProcessing: _processing.contains(r.recommendationId),
                  onClaim: () => _updateStatus(r, 'claim'),
                  onDecline: () => _updateStatus(r, 'decline'),
                  onView: () => _updateStatus(r, 'view'),
                )),
            const SizedBox(height: 20),
          ],
          if (viewed.isNotEmpty) ...[
            _SectionHeader(
              label: 'Viewed',
              count: viewed.length,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            ...viewed.map((r) => _RecommendationCard(
                  rec: r,
                  isProcessing: _processing.contains(r.recommendationId),
                  onClaim: () => _updateStatus(r, 'claim'),
                  onDecline: () => _updateStatus(r, 'decline'),
                )),
            const SizedBox(height: 20),
          ],
          if (claimed.isNotEmpty) ...[
            _SectionHeader(
              label: 'Claimed by you',
              count: claimed.length,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            ...claimed.map(
              (r) => _RecommendationCard(
                rec: r,
                isProcessing: false,
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (declined.isNotEmpty) ...[
            _SectionHeader(
              label: 'Declined',
              count: declined.length,
              color: Colors.grey,
            ),
            const SizedBox(height: 8),
            ...declined.map(
              (r) => _RecommendationCard(rec: r, isProcessing: false),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab label with badge ──────────────────────────────────────────────────────

class MarketplaceTabLabel extends StatelessWidget {
  const MarketplaceTabLabel({super.key, required this.pendingCount});
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Requests'),
        if (pendingCount > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$pendingCount',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

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
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}

// ── Recommendation card ───────────────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.rec,
    required this.isProcessing,
    this.onClaim,
    this.onDecline,
    this.onView,
  });

  final RecommendedRequest rec;
  final bool isProcessing;
  final VoidCallback? onClaim;
  final VoidCallback? onDecline;
  final VoidCallback? onView; // Called when card is first tapped

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final req = rec.request;

    final (statusColor, statusLabel, statusIcon) =
        switch (rec.recommendationStatus) {
      'pending' => (Colors.orange, 'New', Icons.fiber_new_rounded),
      'viewed' => (Colors.blue, 'Viewed', Icons.visibility_outlined),
      'claimed' => (Colors.green, 'Claimed', Icons.check_circle_rounded),
      'declined' => (
          colorScheme.onSurface.withAlpha(128),
          'Declined',
          Icons.do_not_disturb_outlined
        ),
      _ => (Colors.grey, rec.recommendationStatus, Icons.help_outline),
    };

    final bool canAct =
        rec.recommendationStatus == 'pending' ||
        rec.recommendationStatus == 'viewed';

    return GestureDetector(
      onTap: rec.recommendationStatus == 'pending' ? onView : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: rec.recommendationStatus == 'pending'
                ? Colors.orange.withAlpha(77)
                : colorScheme.outline.withAlpha(38),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                // Customer avatar
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    (rec.requesterUsername ?? 'C')[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.requesterUsername ?? 'Customer',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        DateFormat('MMM d, yyyy')
                            .format(req.createdAt.toLocal()),
                        style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurface.withAlpha(128)),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withAlpha(77)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Title ──────────────────────────────────────────────────
            Text(
              req.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),

            // ── Description ────────────────────────────────────────────
            Text(
              req.description,
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: colorScheme.onSurface.withAlpha(200)),
            ),
            const SizedBox(height: 10),

            // ── Meta ───────────────────────────────────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                if (req.category != null)
                  _MetaChip(
                    icon: CategoryIconMapper.fromKey(
                        req.category!.iconKey,
                        fallbackName: req.category!.name),
                    label: req.category!.name,
                  ),
                if (req.city != null && req.city!.isNotEmpty)
                  _MetaChip(
                      icon: Icons.location_on_outlined,
                      label: req.city!),
                if (req.maxBudget != null)
                  _MetaChip(
                    icon: Icons.attach_money_rounded,
                    label:
                        'Budget: \$${req.maxBudget!.toStringAsFixed(0)}',
                  ),
                if (req.neededBy != null)
                  _MetaChip(
                    icon: Icons.event_outlined,
                    label:
                        'By ${DateFormat('MMM d').format(req.neededBy!.toLocal())}',
                  ),
              ],
            ),

            // ── Actions ────────────────────────────────────────────────
            if (canAct && (onClaim != null || onDecline != null)) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onDecline != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isProcessing ? null : onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(
                              color: colorScheme.error.withAlpha(77)),
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                  if (onDecline != null && onClaim != null)
                    const SizedBox(width: 10),
                  if (onClaim != null)
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: isProcessing ? null : onClaim,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        icon: isProcessing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Icon(Icons.handshake_rounded,
                                size: 16),
                        label: const Text("I can help"),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colorScheme.onSurface.withAlpha(128)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withAlpha(153))),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined,
                size: 52, color: colorScheme.onSurface.withAlpha(51)),
            const SizedBox(height: 14),
            Text('No recommendations yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'When customers post requests matching your\nbusiness category and city, they\'ll appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5,
                  color: colorScheme.onSurface.withAlpha(115),
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}