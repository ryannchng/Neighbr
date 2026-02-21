import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/category_icon_mapper.dart';
import '../../models/business_model.dart';
import '../../repositories/favourites_repository.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final _repo = FavouritesRepository();

  List<Business> _saved = [];
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
      final saved = await _repo.getSaved();
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load saved places.';
        _loading = false;
      });
    }
  }

  Future<void> _unsave(Business business) async {
    try {
      await _repo.unsave(business.id);
      if (mounted) {
        setState(() => _saved.removeWhere((b) => b.id == business.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${business.name}" removed from saved.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await _repo.save(business.id);
                _load();
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Saved Places')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _saved.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _saved.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                        ),
                        itemBuilder: (context, i) => _SavedTile(
                          business: _saved[i],
                          onTap: () =>
                              context.push('/businesses/${_saved[i].id}'),
                          onUnsave: () => _unsave(_saved[i]),
                        ),
                      ),
                    ),
    );
  }
}

// ── Saved tile ────────────────────────────────────────────────────────────────

class _SavedTile extends StatelessWidget {
  const _SavedTile({
    required this.business,
    required this.onTap,
    required this.onUnsave,
  });
  final Business business;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

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
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 68,
                height: 68,
                child: _Thumbnail(imageUrl: business.primaryImage),
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
                        Icon(Icons.verified_rounded,
                            size: 15, color: colorScheme.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
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
                        Flexible(
                          child: Text(
                            business.category!.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colorScheme.onSurface.withAlpha(140),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StarRow(rating: business.avgRating),
                      const SizedBox(width: 4),
                      Text(
                        business.avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
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
                ],
              ),
            ),
            const SizedBox(width: 4),

            // Unsave button
            IconButton(
              icon: const Icon(Icons.bookmark_rounded),
              color: colorScheme.primary,
              tooltip: 'Remove from saved',
              onPressed: onUnsave,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared mini-widgets ───────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (imageUrl != null) {
      return Image.network(imageUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(colorScheme));
    }
    return _placeholder(colorScheme);
  }

  Widget _placeholder(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.store_outlined,
            size: 26, color: cs.onSurface.withAlpha(64)),
      );
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});
  final double rating;

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
          size: 13,
          color: const Color(0xFFFBBF24),
        );
      }),
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
            Icon(Icons.bookmark_border_rounded,
                size: 52, color: colorScheme.onSurface.withAlpha(51)),
            const SizedBox(height: 14),
            Text(
              'No saved places yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on any business\nto save it here.',
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
