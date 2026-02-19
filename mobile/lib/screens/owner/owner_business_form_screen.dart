import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/business_model.dart';
import '../../models/category_model.dart';
import '../../repositories/owner_repository.dart';

class OwnerBusinessFormScreen extends StatefulWidget {
  /// Pass an existing [Business] to enter edit mode; null = create mode.
  const OwnerBusinessFormScreen({super.key, this.business});
  final Business? business;

  @override
  State<OwnerBusinessFormScreen> createState() =>
      _OwnerBusinessFormScreenState();
}

class _OwnerBusinessFormScreenState extends State<OwnerBusinessFormScreen> {
  final _repo = OwnerRepository();
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ────────────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _websiteCtrl;

  // ── State ───────────────────────────────────────────────────────────────────
  List<Category> _categories = [];
  String? _selectedCategoryId;
  int? _priceRange; // 1-4
  bool _loadingCategories = true;
  bool _saving = false;
  String? _saveError;

  // Business hours: list of 7 entries (Mon-Sun), each has isOpen + open/close
  // Index 0 = Monday … 6 = Sunday
  late List<_HoursEntry> _hours;

  bool get _isEdit => widget.business != null;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _descCtrl = TextEditingController(text: b?.description ?? '');
    _addressCtrl = TextEditingController(text: b?.address ?? '');
    _cityCtrl = TextEditingController(text: b?.city ?? '');
    _provinceCtrl = TextEditingController(text: b?.province ?? '');
    _phoneCtrl = TextEditingController(text: b?.phone ?? '');
    _websiteCtrl = TextEditingController(text: b?.website ?? '');
    _selectedCategoryId = b?.category?.id;
    _priceRange = b?.priceRange;
    _hours = List.generate(7, (i) => _HoursEntry());
    _loadCategories();
    if (_isEdit) _loadHours();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadCategories() async {
    try {
      final cats = await _repo.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _loadHours() async {
    try {
      final raw = await _repo.getBusinessHours(widget.business!.id);
      if (!mounted) return;
      setState(() {
        for (final row in raw) {
          final dayIndex = (row['day_of_week'] as int? ?? 1) - 1;
          if (dayIndex >= 0 && dayIndex < 7) {
            _hours[dayIndex] = _HoursEntry.fromRow(row);
          }
        }
      });
    } catch (_) {
      // Non-fatal; just leave defaults
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      Business saved;
      if (_isEdit) {
        saved = await _repo.updateBusiness(
          id: widget.business!.id,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          categoryId: _selectedCategoryId,
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          province: _provinceCtrl.text.trim().isEmpty
              ? null
              : _provinceCtrl.text.trim(),
          phone:
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          website: _websiteCtrl.text.trim().isEmpty
              ? null
              : _websiteCtrl.text.trim(),
          priceRange: _priceRange,
        );
      } else {
        saved = await _repo.createBusiness(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          categoryId: _selectedCategoryId,
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          province: _provinceCtrl.text.trim().isEmpty
              ? null
              : _provinceCtrl.text.trim(),
          phone:
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          website: _websiteCtrl.text.trim().isEmpty
              ? null
              : _websiteCtrl.text.trim(),
          priceRange: _priceRange,
        );
      }

      // Upsert hours
      final hoursPayload = <Map<String, dynamic>>[];
      for (int i = 0; i < 7; i++) {
        final h = _hours[i];
        if (h.isOpen) {
          hoursPayload.add({
            'day_of_week': i + 1,
            'open_time': h.openTime,
            'close_time': h.closeTime,
          });
        }
      }
      await _repo.upsertBusinessHours(saved.id, hoursPayload);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Failed to save listing. Please try again.';
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Listing' : 'New Listing'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            if (_saveError != null) _buildErrorBanner(colorScheme),
            _buildSectionLabel('Basic Info'),
            _buildNameField(colorScheme),
            const SizedBox(height: 12),
            _buildDescriptionField(colorScheme),
            const SizedBox(height: 12),
            _buildCategoryPicker(colorScheme),
            const SizedBox(height: 12),
            _buildPriceRangePicker(colorScheme),
            const SizedBox(height: 24),
            _buildSectionLabel('Location'),
            _buildTextField(
              controller: _addressCtrl,
              label: 'Street address',
              icon: Icons.location_on_rounded,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _cityCtrl,
                    label: 'City',
                    icon: Icons.location_city_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _provinceCtrl,
                    label: 'Province',
                    icon: Icons.map_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionLabel('Contact'),
            _buildTextField(
              controller: _phoneCtrl,
              label: 'Phone number',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\+\(\)]'))],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _websiteCtrl,
              label: 'Website URL',
              icon: Icons.language_rounded,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            _buildSectionLabel('Business Hours'),
            _buildHoursSection(colorScheme),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Section widgets ─────────────────────────────────────────────────────────

  Widget _buildErrorBanner(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: colorScheme.onErrorContainer, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _saveError!,
              style: TextStyle(
                  color: colorScheme.onErrorContainer, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildNameField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _nameCtrl,
      decoration: _inputDecoration(
        label: 'Business name *',
        icon: Icons.store_rounded,
      ),
      textCapitalization: TextCapitalization.words,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Name is required';
        if (v.trim().length < 2) return 'Name must be at least 2 characters';
        return null;
      },
    );
  }

  Widget _buildDescriptionField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _descCtrl,
      decoration: _inputDecoration(
        label: 'Description *',
        icon: Icons.description_rounded,
      ).copyWith(alignLabelWithHint: true),
      minLines: 3,
      maxLines: 6,
      textCapitalization: TextCapitalization.sentences,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Description is required';
        if (v.trim().length < 20) return 'Please write at least 20 characters';
        return null;
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label: label, icon: icon),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    );
  }

  Widget _buildCategoryPicker(ColorScheme colorScheme) {
    if (_loadingCategories) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      decoration: _inputDecoration(
        label: 'Category',
        icon: Icons.category_rounded,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('No category'),
        ),
        ..._categories.map(
          (cat) => DropdownMenuItem<String>(
            value: cat.id,
            child: Text('${cat.icon} ${cat.name}'),
          ),
        ),
      ],
      onChanged: (v) => setState(() => _selectedCategoryId = v),
    );
  }

  Widget _buildPriceRangePicker(ColorScheme colorScheme) {
    const options = [
      (1, r'$', 'Inexpensive'),
      (2, r'$$', 'Moderate'),
      (3, r'$$$', 'Expensive'),
      (4, r'$$$$', 'Very expensive'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_money_rounded,
                size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Price range',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: options.map((opt) {
            final (value, symbol, tooltip) = opt;
            final selected = _priceRange == value;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: value < 4 ? 8 : 0),
                child: Tooltip(
                  message: tooltip,
                  child: GestureDetector(
                    onTap: () => setState(() =>
                        _priceRange = selected ? null : value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.outline.withAlpha(77),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        symbol,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: selected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface.withAlpha(140),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHoursSection(ColorScheme colorScheme) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withAlpha(51)),
      ),
      child: Column(
        children: List.generate(7, (i) {
          final h = _hours[i];
          final isLast = i == 6;

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Day label
                    SizedBox(
                      width: 36,
                      child: Text(
                        dayNames[i],
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Open/closed switch
                    Switch(
                      value: h.isOpen,
                      onChanged: (v) => setState(() => _hours[i].isOpen = v),
                    ),

                    const SizedBox(width: 8),

                    if (h.isOpen) ...[
                      // Open time
                      Expanded(
                        child: _TimePickerButton(
                          label: h.openTime,
                          onTap: () async {
                            final t = await _pickTime(context, h.openTime);
                            if (t != null) {
                              setState(() => _hours[i].openTime = t);
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('–',
                            style: TextStyle(
                                color: colorScheme.onSurface.withAlpha(128))),
                      ),
                      // Close time
                      Expanded(
                        child: _TimePickerButton(
                          label: h.closeTime,
                          onTap: () async {
                            final t = await _pickTime(context, h.closeTime);
                            if (t != null) {
                              setState(() => _hours[i].closeTime = t);
                            }
                          },
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          'Closed',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withAlpha(102),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: colorScheme.outline.withAlpha(38)),
            ],
          );
        }),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    );
  }

  Future<String?> _pickTime(BuildContext context, String current) async {
    // Parse "HH:MM" → TimeOfDay
    final parts = current.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 9, minute: 0);

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return null;
    final h = picked.hour.toString().padLeft(2, '0');
    final m = picked.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ============================================================================
// Hours entry model
// ============================================================================

class _HoursEntry {
  bool isOpen;
  String openTime;
  String closeTime;

  _HoursEntry({
    this.isOpen = false,
    this.openTime = '09:00',
    this.closeTime = '17:00',
  });

  factory _HoursEntry.fromRow(Map<String, dynamic> row) {
    return _HoursEntry(
      isOpen: true,
      openTime: (row['open_time'] as String?)?.substring(0, 5) ?? '09:00',
      closeTime: (row['close_time'] as String?)?.substring(0, 5) ?? '17:00',
    );
  }
}

// ============================================================================
// Time picker button
// ============================================================================

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline.withAlpha(77)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time_rounded,
                size: 13, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}