import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../repositories/review_repository.dart';

class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({super.key, required this.businessId, required this.businessName});

  final String businessId;
  final String businessName;

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _contentController = TextEditingController();
  int _rating = 0;
  bool _isVerifiedVisit = false;
  bool _submitting = false;
  bool get _isGuest => SupabaseClientProvider.currentUser?.isAnonymous ?? false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guests cannot submit reviews.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a star rating before submitting.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final repo = ReviewRepository();
      await repo.submitReview(
        businessId: widget.businessId,
        rating: _rating,
        content: _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        isVerifiedVisit: _isVerifiedVisit,
      );

      if (!mounted) return;
      context.pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted. Thank you!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e.toString())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _friendlyError(String raw) {
    if (raw.toLowerCase().contains('guest')) {
      return 'Guests cannot submit reviews.';
    }
    if (raw.contains('already')) return 'You have already reviewed this business.';
    if (raw.contains('network') || raw.contains('socket')) {
      return 'Network error. Check your connection and try again.';
    }
    return 'Could not submit review. Please try again.';
  }

  String _ratingLabel() {
    switch (_rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very good';
      case 5:
        return 'Excellent';
      default:
        return 'Tap to rate';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Write a Review'),
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _isGuest ? null : _submit,
              child: const Text(
                'Submit',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // Business name header
          Text(
            widget.businessName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Share your experience with others.',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withAlpha(140),
            ),
          ),
          const SizedBox(height: 28),

          // ── Star rating ──────────────────────────────────────────────────
          _SectionLabel(label: 'Your Rating'),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            star <= _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            key: ValueKey('$star-${star <= _rating}'),
                            size: 44,
                            color: star <= _rating
                                ? const Color(0xFFFBBF24)
                                : colorScheme.onSurface.withAlpha(77),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _ratingLabel(),
                    key: ValueKey(_rating),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          _rating > 0 ? FontWeight.w600 : FontWeight.w400,
                      color: _rating > 0
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withAlpha(102),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Written review ───────────────────────────────────────────────
          _SectionLabel(label: 'Your Review (optional)'),
          const SizedBox(height: 10),
          TextField(
            controller: _contentController,
            minLines: 5,
            maxLines: 10,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText:
                  'What did you like or dislike? How was the service, atmosphere, or value?',
              hintStyle: TextStyle(
                color: colorScheme.onSurface.withAlpha(102),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withAlpha(77),
              alignLabelWithHint: true,
              counterStyle: TextStyle(
                color: colorScheme.onSurface.withAlpha(102),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Verified visit toggle ────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withAlpha(38)),
            ),
            child: SwitchListTile(
              value: _isVerifiedVisit,
              onChanged: (v) => setState(() => _isVerifiedVisit = v),
              title: const Text(
                'I visited this business in person',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Marks your review as a verified visit',
                style: TextStyle(
                  fontSize: 12.5,
                  color: colorScheme.onSurface.withAlpha(115),
                ),
              ),
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Guidelines ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha(102),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Review guidelines',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _GuidelineItem(
                    text: 'Be honest and based on your real experience.'),
                _GuidelineItem(
                    text: 'Keep it respectful — no personal attacks.'),
                _GuidelineItem(
                    text: 'No spam, promotional content, or irrelevant links.'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Submit button ────────────────────────────────────────────────
          FilledButton(
            onPressed: (_submitting || _isGuest) ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(_isGuest ? 'Unavailable for guests' : 'Submit Review'),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: colorScheme.onSurface.withAlpha(128),
      ),
    );
  }
}

class _GuidelineItem extends StatelessWidget {
  const _GuidelineItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_rounded,
              size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: colorScheme.onSurface.withAlpha(179),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
