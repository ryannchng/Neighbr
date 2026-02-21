import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/supabase_client.dart';
import '../../models/business_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/business_request_repository.dart';
import '../../repositories/owner_repository.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _repo = OwnerRepository();
  final _authRepo = AuthRepository();
  final _requestRepo = BusinessRequestRepository();

  List<Business> _businesses = [];
  // Map of business ID → open request count
  Map<String, int> _requestCounts = {};
  bool _loading = true;
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
      final businesses = await _repo.getMyBusinesses();

      // Fetch open request counts for all businesses in parallel
      Map<String, int> requestCounts = {};
      if (businesses.isNotEmpty) {
        final counts = await Future.wait(
          businesses.map((b) => _requestRepo
              .getOutstandingCountForBusinesses([b.id])
              .then((count) => MapEntry(b.id, count))),
        );
        requestCounts = Map.fromEntries(counts);
      }

      if (!mounted) return;
      setState(() {
        _businesses = businesses;
        _requestCounts = requestCounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load your listings.';
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await _authRepo.signOut();
    if (mounted) context.go(AppRoutes.login);
  }

  void _createBusiness() {
    context.push(AppRoutes.ownerBusinessForm).then((_) => _load());
  }

  void _openBusiness(Business b) {
    context
        .push(AppRoutes.ownerBusinessDetail.replaceFirst(':id', b.id))
        .then((_) => _load());
  }

  // -------------------------------------------------------------------------
  // Summary totals across all businesses
  // -------------------------------------------------------------------------

  int get _totalReviews =>
      _businesses.fold(0, (acc, b) => acc + b.reviewCount);

  int get _totalOpenRequests =>
      _requestCounts.values.fold(0, (acc, c) => acc + c);

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final username =
        SupabaseClientProvider.currentUser?.email?.split('@').first ?? 'Owner';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(colorScheme, username),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: _ErrorView(message: _error!, onRetry: _load),
                )
              else ...[
                if (_businesses.isNotEmpty) _buildSummaryCards(colorScheme),
                _buildSectionHeader(
                    '${_businesses.length} Listing${_businesses.length == 1 ? '' : 's'}'),
                if (_businesses.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState(colorScheme))
                else
                  _buildBusinessList(),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBusiness,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add Listing'),
      ),
    );
  }

  Widget _buildAppBar(ColorScheme colorScheme, String username) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.profile);
                }
              },
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owner Portal',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withAlpha(128),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hello, $username 👋',
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
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'signout') _signOut();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'signout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Sign out'),
                    ],
                  ),
                ),
              ],
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(ColorScheme colorScheme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.store_rounded,
                label: 'Listings',
                value: '${_businesses.length}',
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.reviews_rounded,
                label: 'Reviews',
                value: '$_totalReviews',
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.campaign_rounded,
                label: 'Requests',
                value: '$_totalOpenRequests',
                color: _totalOpenRequests > 0 ? Colors.red : colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildBusinessList() {
    return SliverList.separated(
      itemCount: _businesses.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 20, endIndent: 20),
      itemBuilder: (context, i) {
        final business = _businesses[i];
        final openRequests = _requestCounts[business.id] ?? 0;
        return _BusinessOwnerTile(
          business: business,
          openRequestCount: openRequests,
          onTap: () => _openBusiness(business),
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined,
                size: 64, color: colorScheme.onSurface.withAlpha(51)),
            const SizedBox(height: 16),
            Text(
              'No listings yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to create\nyour first business listing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withAlpha(128),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Sub-widgets
// ============================================================================

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: colorScheme.onSurface.withAlpha(128),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessOwnerTile extends StatelessWidget {
  const _BusinessOwnerTile({
    required this.business,
    required this.openRequestCount,
    required this.onTap,
  });

  final Business business;
  final int openRequestCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Thumbnail with badge overlay
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 62,
                    height: 62,
                    color: colorScheme.surfaceContainerHighest,
                    child: business.primaryImage != null
                        ? Image.network(
                            business.primaryImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.store_outlined,
                              color: colorScheme.onSurface.withAlpha(64),
                            ),
                          )
                        : Icon(
                            Icons.store_outlined,
                            color: colorScheme.onSurface.withAlpha(64),
                          ),
                  ),
                ),
                // Red badge
                if (openRequestCount > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: openRequestCount > 9
                          ? const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2)
                          : const EdgeInsets.all(0),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: openRequestCount > 9
                            ? BoxShape.rectangle
                            : BoxShape.circle,
                        borderRadius: openRequestCount > 9
                            ? BorderRadius.circular(10)
                            : null,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        openRequestCount > 99
                            ? '99+'
                            : '$openRequestCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
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
                      if (business.isVerified)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.verified_rounded,
                              size: 15, color: colorScheme.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 13, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 3),
                      Text(
                        business.avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        ' (${business.reviewCount} review${business.reviewCount == 1 ? '' : 's'})',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withAlpha(115),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (business.location != null)
                        Expanded(
                          child: Text(
                            business.location!,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withAlpha(115),
                            ),
                          ),
                        ),
                      if (openRequestCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(26),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.red.withAlpha(77)),
                          ),
                          child: Text(
                            '$openRequestCount open request${openRequestCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
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
            Icon(Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withAlpha(77)),
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
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withAlpha(140))),
            const SizedBox(height: 20),
            FilledButton.tonal(
                onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
