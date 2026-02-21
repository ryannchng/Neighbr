import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:profanity_filter/profanity_filter.dart';

import '../../models/user_profile_model.dart';
import '../../repositories/profile_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _repo = ProfileRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _usernameCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;

  final _usernameFocus = FocusNode();
  final _imagePicker = ImagePicker();

  File? _newAvatarFile;
  Set<String> _selectedInterests = {};

  bool _saving = false;
  String? _error;

  static const _kInterests = [
    ('food', 'Food & Dining', '🍽️'),
    ('retail', 'Retail', '🛍️'),
    ('services', 'Services', '🔧'),
    ('health', 'Health & Wellness', '💪'),
    ('entertainment', 'Entertainment', '🎭'),
    ('beauty', 'Beauty', '💅'),
  ];

  static final _profanityFilter = ProfanityFilter();

  @override
  void initState() {
    super.initState();
    _usernameCtrl =
        TextEditingController(text: widget.profile.username ?? '');
    _nameCtrl =
        TextEditingController(text: widget.profile.fullName ?? '');
    _cityCtrl = TextEditingController(text: widget.profile.city ?? '');
    _selectedInterests = Set.from(widget.profile.interests);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  String? _validateUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Username is required.';
    if (v.contains(' ')) return 'Username cannot contain spaces.';
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(v)) {
      return 'Only letters, numbers, and . _ - are allowed.';
    }
    if (v.length < 3) return 'At least 3 characters.';
    if (v.length > 30) return '30 characters maximum.';
    if (_profanityFilter.hasProfanity(v)) {
      return 'That username isn\'t allowed.';
    }
    return null;
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    final colorScheme = Theme.of(context).colorScheme;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outline.withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('Choose photo',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(Icons.camera_alt_rounded,
                      color: colorScheme.onPrimaryContainer),
                ),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Icon(Icons.photo_library_rounded,
                      color: colorScheme.onSecondaryContainer),
                ),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              if (_newAvatarFile != null ||
                  widget.profile.avatarUrl != null) ...[
                const Divider(height: 8),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.errorContainer,
                    child: Icon(Icons.delete_outline_rounded,
                        color: colorScheme.onErrorContainer),
                  ),
                  title: const Text('Remove photo'),
                  onTap: () {
                    setState(() => _newAvatarFile = null);
                    Navigator.pop(ctx);
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _newAvatarFile = File(picked.path));
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.saveProfile(
        username: _usernameCtrl.text.trim(),
        // Pass the name even if empty so the repository can write it.
        // We send null only when the field was never touched; here we always
        // have a value (possibly empty string which we normalise to null).
        fullName: _nameCtrl.text.trim().isEmpty
            ? null
            : _nameCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty
            ? null
            : _cityCtrl.text.trim(),
        avatarFile: _newAvatarFile,
        interests: _selectedInterests.toList(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save profile. Please try again.';
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    ImageProvider? avatarImage;
    if (_newAvatarFile != null) {
      avatarImage = FileImage(_newAvatarFile!);
    } else if (widget.profile.avatarUrl != null) {
      avatarImage = NetworkImage(widget.profile.avatarUrl!);
    }

    final initials = _usernameCtrl.text.isNotEmpty
        ? _usernameCtrl.text[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // ── AppBar – no save button; saving is done via the bottom button only
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],

            // ── Avatar ─────────────────────────────────────────────────────
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              initials,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2.5,
                        ),
                      ),
                      child: Icon(Icons.camera_alt_rounded,
                          size: 16, color: colorScheme.onPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _pickAvatar,
                child: const Text('Change photo'),
              ),
            ),
            const SizedBox(height: 24),

            // ── Username ───────────────────────────────────────────────────
            _SectionLabel(label: 'Username'),
            TextFormField(
              controller: _usernameCtrl,
              focusNode: _usernameFocus,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 30,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9._-]')),
              ],
              validator: _validateUsername,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Username *',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                helperText: 'Letters, numbers, and . _ - only',
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            // ── Name ───────────────────────────────────────────────────────
            _SectionLabel(label: 'Display Name'),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Full name',
                prefixIcon: const Icon(Icons.badge_outlined),
                helperText: 'How you\'ll appear to others',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            // ── City ───────────────────────────────────────────────────────
            _SectionLabel(label: 'Location'),
            TextFormField(
              controller: _cityCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: 'City',
                prefixIcon: const Icon(Icons.location_city_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 28),

            // ── Interests ──────────────────────────────────────────────────
            _SectionLabel(label: 'Interests'),
            const SizedBox(height: 4),
            Text(
              'Personalises your recommendations.',
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withAlpha(128)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _kInterests.map((interest) {
                final (id, label, emoji) = interest;
                final selected = _selectedInterests.contains(id);
                return _InterestChip(
                  id: id,
                  label: label,
                  emoji: emoji,
                  selected: selected,
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedInterests.remove(id);
                    } else {
                      _selectedInterests.add(id);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // ── Save button (sole save action) ─────────────────────────────
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Save Changes',
                      style: TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: colorScheme.onSurface.withAlpha(128),
        ),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.id,
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });
  final String id;
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        avatar: Text(emoji, style: const TextStyle(fontSize: 15)),
        label: Text(label,
            style: TextStyle(
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400)),
        onSelected: (_) => onTap(),
        backgroundColor:
            colorScheme.surfaceContainerHighest.withAlpha(128),
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(
          color: selected
              ? colorScheme.primary.withAlpha(102)
              : colorScheme.outline.withAlpha(51),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            child: Text(message,
                style: TextStyle(
                    color: colorScheme.onErrorContainer, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}