import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/category_icon_mapper.dart';
import '../../core/supabase_client.dart';
import '../../models/category_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/marketplace_request_repository.dart';

class WriteMarketplaceRequestScreen extends StatefulWidget {
  const WriteMarketplaceRequestScreen({super.key});

  @override
  State<WriteMarketplaceRequestScreen> createState() =>
      _WriteMarketplaceRequestScreenState();
}

class _WriteMarketplaceRequestScreenState
    extends State<WriteMarketplaceRequestScreen> {
  final _repo = MarketplaceRequestRepository();
  final _bizRepo = BusinessRepository();

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

  List<Category> _categories = [];
  String? _selectedCategoryId;
  DateTime? _neededBy;
  bool _submitting = false;
  bool _loadingCats = true;

  bool get _isGuest =>
      SupabaseClientProvider.currentUser?.isAnonymous ?? false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _bizRepo.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCats = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _neededBy = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final budgetText = _budgetCtrl.text.trim();
    final budget = budgetText.isEmpty ? null : double.tryParse(budgetText);
    if (budgetText.isNotEmpty && budget == null) {
      _showSnack('Budget must be a valid number.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final req = await _repo.createRequest(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        categoryId: _selectedCategoryId,
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        maxBudget: budget,
        neededBy: _neededBy,
      );

      if (!mounted) return;
      context.pop(req);
      _showSnack(
        'Request posted! We\'ve matched it to relevant local businesses.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // _showSnack('Error: $e'); // temporary — remove before production
      _showSnack('Could not post request. Please try again.');
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Post a Request')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            // ── How it works banner ──────────────────────────────────────
            _InfoBanner(colorScheme: colorScheme),
            const SizedBox(height: 24),

            // ── Title ────────────────────────────────────────────────────
            _SectionLabel(label: 'What do you need?'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              validator: (v) {
                if (v == null || v.trim().length < 5) {
                  return 'Please write a short title (at least 5 characters).';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: 'e.g. Birthday cake for 20 people',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),

            // ── Description ───────────────────────────────────────────────
            _SectionLabel(label: 'More details'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              minLines: 4,
              maxLines: 8,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              validator: (v) {
                if (v == null || v.trim().length < 20) {
                  return 'Please add at least 20 characters of detail.';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText:
                    'Describe what you\'re looking for, any preferences, '
                    'timeline, or special requirements…',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                counterText: '',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // ── Category ──────────────────────────────────────────────────
            _SectionLabel(label: 'Category (optional)'),
            const SizedBox(height: 8),
            _CategoryPicker(
              categories: _categories,
              loading: _loadingCats,
              selectedId: _selectedCategoryId,
              onSelected: (id) =>
                  setState(() => _selectedCategoryId = id),
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 20),

            // ── City ──────────────────────────────────────────────────────
            _SectionLabel(label: 'City (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cityCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'e.g. Vancouver',
                prefixIcon: const Icon(Icons.location_city_outlined),
                helperText:
                    'Limits matches to businesses in your city',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 20),

            // ── Budget + Date row ─────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(label: 'Max budget'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _budgetCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          prefixText: '\$',
                          hintText: '100',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(label: 'Needed by'),
                      const SizedBox(height: 8),
                      _DateButton(
                        date: _neededBy,
                        onTap: _pickDate,
                        onClear: () => setState(() => _neededBy = null),
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Submit ────────────────────────────────────────────────────
            FilledButton.icon(
              onPressed: (_submitting || _isGuest) ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isGuest
                    ? 'Sign in to post a request'
                    : _submitting
                        ? 'Posting…'
                        : 'Post Request',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'How it works',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...[
            ('1', 'Describe what you need', Icons.edit_note_rounded),
            ('2', 'We match your request to relevant local businesses',
                Icons.store_rounded),
            ('3', 'Businesses reach out to help you',
                Icons.handshake_rounded),
          ].map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        step.$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step.$2,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withAlpha(200),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category picker ───────────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.loading,
    required this.selectedId,
    required this.onSelected,
    required this.colorScheme,
  });

  final List<Category> categories;
  final bool loading;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(77),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "Any" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Any'),
              selected: selectedId == null,
              showCheckmark: false,
              onSelected: (_) => onSelected(null),
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withAlpha(128),
              selectedColor: colorScheme.primaryContainer,
              side: BorderSide(
                color: selectedId == null
                    ? colorScheme.primary.withAlpha(102)
                    : colorScheme.outline.withAlpha(51),
              ),
            ),
          ),
          ...categories.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(
                  CategoryIconMapper.fromKey(cat.iconKey,
                      fallbackName: cat.name),
                  size: 14,
                  color: selectedId == cat.id
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface.withAlpha(166),
                ),
                label: Text(cat.name),
                selected: selectedId == cat.id,
                showCheckmark: false,
                onSelected: (_) => onSelected(cat.id),
                backgroundColor:
                    colorScheme.surfaceContainerHighest.withAlpha(128),
                selectedColor: colorScheme.primaryContainer,
                side: BorderSide(
                  color: selectedId == cat.id
                      ? colorScheme.primary.withAlpha(102)
                      : colorScheme.outline.withAlpha(51),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date button ───────────────────────────────────────────────────────────────

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.date,
    required this.onTap,
    required this.onClear,
    required this.colorScheme,
  });

  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(77),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate
                ? colorScheme.primary.withAlpha(102)
                : colorScheme.outline.withAlpha(102),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_outlined,
              size: 18,
              color: hasDate
                  ? colorScheme.primary
                  : colorScheme.onSurface.withAlpha(128),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasDate
                    ? '${date!.month}/${date!.day}/${date!.year}'
                    : 'Optional',
                style: TextStyle(
                  fontSize: 13.5,
                  color: hasDate
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withAlpha(102),
                ),
              ),
            ),
            if (hasDate)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 16,
                    color: colorScheme.onSurface.withAlpha(128)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

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