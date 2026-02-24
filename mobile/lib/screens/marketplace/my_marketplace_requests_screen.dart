import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/category_icon_mapper.dart';
import '../../repositories/marketplace_request_repository.dart';

class MyMarketplaceRequestsScreen extends StatefulWidget {
  const MyMarketplaceRequestsScreen({super.key});

  @override
  State<MyMarketplaceRequestsScreen> createState() =>
      _MyMarketplaceRequestsScreenState();
}

class _MyMarketplaceRequestsScreenState
    extends State<MyMarketplaceRequestsScreen> {
  final _repo = MarketplaceRequestRepository();

  List<MarketplaceRequest> _requests = [];
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
      final requests = await _repo.getMyRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your requests.';
        _loading = false;
      });
    }
  }

  Future<void> _cancelRequest(MarketplaceRequest req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Cancel request?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  '"${req.title}" will be cancelled and removed from matched businesses.'),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: OutlinedButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                  side: BorderSide.none,
                ),
                child: const Text('Cancel Request'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep it'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _repo.cancelRequest(req.id);
      if (mounted) {
        setState(() {
          final idx = _requests.indexWhere((r) => r.id == req.id);
          if (idx != -1) {
            _requests[idx] = MarketplaceRequest(
              id: req.id,
              userId: req.userId,
              title: req.title,
              description: req.description,
              status: 'cancelled',
              createdAt: req.createdAt,
              category: req.category,
              city: req.city,
              maxBudget: req.maxBudget,
              neededBy: req.neededBy,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not cancel. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openCreateRequest() async {
    final result = await context.push<MarketplaceRequest>(
      '/marketplace/new',
    );
    if (result != null && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('My Requests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateRequest,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Request'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _requests.isEmpty
                  ? _EmptyState(onPost: _openCreateRequest)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) => _RequestCard(
                          request: _requests[i],
                          onCancel: _requests[i].isOpen
                              ? () => _cancelRequest(_requests[i])
                              : null,
                        ),
                      ),
                    ),
    );
  }
}

// ── Request card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, this.onCancel});

  final MarketplaceRequest request;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (chipColor, chipLabel, chipIcon) = switch (request.status) {
      'open' => (
          colorScheme.primary,
          'Open',
          Icons.radio_button_unchecked_rounded
        ),
      'fulfilled' => (Colors.green, 'Fulfilled', Icons.check_circle_rounded),
      'cancelled' => (
          colorScheme.onSurface.withAlpha(128),
          'Cancelled',
          Icons.cancel_outlined
        ),
      _ => (Colors.grey, request.status, Icons.help_outline),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withAlpha(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15.5),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: chipColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Description ────────────────────────────────────────────────
          Text(
            request.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: colorScheme.onSurface.withAlpha(200),
            ),
          ),
          const SizedBox(height: 10),

          // ── Meta chips ─────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: Icons.calendar_today_outlined,
                label: _formatDate(request.createdAt),
              ),
              if (request.category != null)
                _MetaChip(
                  icon: CategoryIconMapper.fromKey(
                      request.category!.iconKey,
                      fallbackName: request.category!.name),
                  label: request.category!.name,
                ),
              if (request.city != null && request.city!.isNotEmpty)
                _MetaChip(
                    icon: Icons.location_on_outlined,
                    label: request.city!),
              if (request.maxBudget != null)
                _MetaChip(
                  icon: Icons.attach_money_rounded,
                  label: 'Up to \$${request.maxBudget!.toStringAsFixed(0)}',
                ),
              if (request.neededBy != null)
                _MetaChip(
                  icon: Icons.event_outlined,
                  label:
                      'By ${_formatDate(request.neededBy!.toLocal())}',
                ),
            ],
          ),

          // ── Cancel action ──────────────────────────────────────────────
          if (onCancel != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: const Text('Cancel request'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    textStyle: const TextStyle(fontSize: 13),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

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
                fontSize: 12, color: colorScheme.onSurface.withAlpha(153))),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPost});
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.campaign_rounded,
                  size: 40, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 20),
            Text('No requests yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Post a request and let local businesses\ncome to you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withAlpha(115),
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPost,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Post a Request'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
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