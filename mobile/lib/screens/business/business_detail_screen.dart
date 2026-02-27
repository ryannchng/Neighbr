import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/business_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/favourites_repository.dart';
import '../../repositories/owner_repository.dart';
import '../../repositories/review_repository.dart';

class BusinessDetailScreen extends StatefulWidget {
  const BusinessDetailScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  final _repo = BusinessRepository();
  final _favouritesRepo = FavouritesRepository();
  final _reviewRepo = ReviewRepository();
  final _ownerRepo = OwnerRepository();

  Business? _business;
  List<_BusinessHoursRow> _hours = [];
  List<ReviewSummary> _reviews = [];
  bool _loading = true;
  bool _saved = false;
  bool _togglingSaved = false;
  bool _hasReviewed = false;
  String? _error;

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
      final results = await Future.wait<dynamic>([
        _repo.getById(widget.businessId),
        _favouritesRepo.isSaved(widget.businessId),
        _repo.getBusinessHours(widget.businessId),
        _reviewRepo.hasReviewed(widget.businessId),
        _ownerRepo.getReviews(widget.businessId),
      ]);
      if (!mounted) return;
      setState(() {
        _business = results[0] as Business?;
        _saved = results[1] as bool;
        _hours = _buildWeeklyHours(
          List<Map<String, dynamic>>.from(results[2] as List),
        );
        _hasReviewed = results[3] as bool;
        _reviews = results[4] as List<ReviewSummary>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this business.';
        _loading = false;
      });
    }
  }

  List<_BusinessHoursRow> _buildWeeklyHours(List<Map<String, dynamic>> rows) {
    final byDay = <int, _BusinessHoursRow>{};
    for (final row in rows) {
      final day = (row['day_of_week'] as int?) ?? 1;
      final open = (row['open_time'] as String?)?.substring(0, 5);
      final close = (row['close_time'] as String?)?.substring(0, 5);
      byDay[day] = _BusinessHoursRow(
        dayOfWeek: day,
        openTime: open,
        closeTime: close,
      );
    }
    return List.generate(7, (i) {
      final day = i + 1;
      return byDay[day] ?? _BusinessHoursRow(dayOfWeek: day);
    });
  }

  String _formatHour(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return value;
    final hour24 = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final mm = minute.toString().padLeft(2, '0');
    return '$hour12:$mm $period';
  }

  Future<void> _toggleSaved() async {
    if (_togglingSaved || _business == null) return;
    setState(() => _togglingSaved = true);
    try {
      final newSaved = await _favouritesRepo.toggle(_business!.id);
      if (!mounted) return;
      setState(() {
        _saved = newSaved;
        _togglingSaved = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newSaved
                ? '"${_business!.name}" saved.'
                : '"${_business!.name}" removed from saved.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _togglingSaved = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update saved status.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openWriteReview() async {
    final business = _business;
    if (business == null) return;
    final result = await context.push<bool>(
      '/businesses/${business.id}/review',
      extra: {'businessName': business.name},
    );
    if (result == true && mounted) _load();
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(business.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: _togglingSaved ? null : _toggleSaved,
            icon: _togglingSaved
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                  ),
            tooltip: _saved ? 'Remove from saved' : 'Save',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // Hero image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _BusinessImage(imageUrl: business.primaryImage),
              ),
            ),
            const SizedBox(height: 14),

            // Name + verified
            Row(
              children: [
                Expanded(
                  child: Text(
                    business.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                if (business.isVerified)
                  Icon(Icons.verified_rounded, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 8),

            // Pills
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (business.category != null)
                  _Pill(label: business.category!.name, icon: Icons.category_rounded),
                _Pill(
                  label: '${business.avgRating.toStringAsFixed(1)} (${business.reviewCount})',
                  icon: Icons.star_rounded,
                ),
                if (business.priceRangeLabel != null)
                  _Pill(label: business.priceRangeLabel!, icon: Icons.attach_money_rounded),
              ],
            ),

            // Location
            if (business.location != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 18,
                      color: colorScheme.onSurface.withAlpha(153)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(business.location!,
                        style: TextStyle(color: colorScheme.onSurface.withAlpha(190))),
                  ),
                ],
              ),
              if (business.address != null && business.address!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.home_outlined, size: 18,
                        color: colorScheme.onSurface.withAlpha(153)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(business.address!.trim(),
                          style: TextStyle(color: colorScheme.onSurface.withAlpha(190))),
                    ),
                  ],
                ),
              ],
            ],

            // About
            if (business.description.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('About',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                business.description,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: colorScheme.onSurface.withAlpha(210),
                ),
              ),
            ],

            // Hours
            if (_hours.isNotEmpty) ...[
              const SizedBox(height: 18),
              _HoursCard(rows: _hours, formatHour: _formatHour),
            ],

            // Contact
            const SizedBox(height: 20),
            if (business.phone != null || business.website != null)
              _ContactCard(business: business),

            const SizedBox(height: 18),

            // ── Actions ────────────────────────────────────────────────────
            if (_hasReviewed)
              _AlreadyReviewedBanner()
            else
              FilledButton.icon(
                onPressed: _openWriteReview,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Write a review'),
              ),

            // ── Reviews ────────────────────────────────────────────────────
            const SizedBox(height: 28),
            Row(
              children: [
                const Text('Reviews',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                if (_reviews.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_reviews.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (_reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No reviews yet. Be the first!',
                  style: TextStyle(
                      color: colorScheme.onSurface.withAlpha(128), fontSize: 14),
                ),
              )
            else
              ..._reviews.map((r) => _ReviewCard(review: r)),
          ],
        ),
      ),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ReviewSummary review;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat('MMM d, yyyy').format(review.createdAt.toLocal());

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
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  review.authorUsername.isNotEmpty
                      ? review.authorUsername[0].toUpperCase()
                      : '?',
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
                    Text(review.authorUsername,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text(dateStr,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurface.withAlpha(128))),
                  ],
                ),
              ),
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
          if (review.content != null && review.content!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.content!,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: colorScheme.onSurface.withAlpha(210)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Already reviewed banner ───────────────────────────────────────────────────

class _AlreadyReviewedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(153),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withAlpha(51)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You\'ve already reviewed this business.',
              style: TextStyle(
                fontSize: 13.5,
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hours ─────────────────────────────────────────────────────────────────────

class _BusinessHoursRow {
  const _BusinessHoursRow({
    required this.dayOfWeek,
    this.openTime,
    this.closeTime,
  });

  final int dayOfWeek;
  final String? openTime;
  final String? closeTime;

  bool get isOpen => openTime != null && closeTime != null;
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.rows, required this.formatHour});

  final List<_BusinessHoursRow> rows;
  final String Function(String) formatHour;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
          const Text('Hours',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          ...rows.map((row) {
            final dayLabel = dayNames[row.dayOfWeek - 1];
            final value = row.isOpen
                ? '${formatHour(row.openTime!)} - ${formatHour(row.closeTime!)}'
                : 'Closed';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(dayLabel,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(value,
                      style: TextStyle(
                        fontSize: 13,
                        color: row.isOpen
                            ? colorScheme.onSurface.withAlpha(200)
                            : colorScheme.onSurface.withAlpha(128),
                      )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Contact ───────────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.business});

  final Business business;

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
          const Text('Contact',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          if (business.phone != null)
            _ContactRow(icon: Icons.phone_outlined, value: business.phone!),
          if (business.website != null)
            _ContactRow(icon: Icons.language_outlined, value: business.website!),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: TextStyle(color: colorScheme.onSurface.withAlpha(205))),
          ),
        ],
      ),
    );
  }
}

// ── Pill ──────────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ── Business image ────────────────────────────────────────────────────────────

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
        errorBuilder: (_, __, ___) => _placeholder(colorScheme),
      );
    }
    return _placeholder(colorScheme);
  }

  Widget _placeholder(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.store_outlined,
              size: 32, color: cs.onSurface.withAlpha(64)),
        ),
      );
}
