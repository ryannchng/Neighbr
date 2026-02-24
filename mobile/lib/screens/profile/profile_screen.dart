import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/router.dart';
import '../../core/supabase_client.dart';
import '../../models/user_profile_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authRepo = AuthRepository();
  final _profileRepo = ProfileRepository();

  bool _loading = true;
  bool _isOwner = false;
  bool _signingOut = false;

  UserProfile? _profile;

  String get _email => SupabaseClientProvider.currentUser?.email ?? '';

  String get _displayName {
    final name = _profile?.fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final username = _profile?.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    return _email.split('@').first;
  }

  String get _initials {
    final parts = _displayName.split(RegExp(r'[\s._-]+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = SupabaseClientProvider.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final row = await SupabaseClientProvider.client
          .from('users')
          .select('id, role, username, full_name, city, avatar_url, interests')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (row != null) {
        setState(() {
          _isOwner = (row['role'] as String?) == AppConstants.roleOwner;
          _profile = UserProfile.fromJson(row);
          _loading = false;
        });
      } else {
        final meta = user.userMetadata ?? {};
        setState(() {
          _isOwner = false;
          _profile = UserProfile(
            id: user.id,
            username:
                meta['username'] as String? ?? (user.email?.split('@').first),
          );
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      final meta = SupabaseClientProvider.currentUser?.userMetadata ?? {};
      setState(() {
        _profile = UserProfile(
          id: SupabaseClientProvider.currentUser!.id,
          username:
              meta['username'] as String? ??
              (_email.isNotEmpty ? _email.split('@').first : null),
        );
        _loading = false;
      });
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;

    await context.push<bool>(AppRoutes.editProfile, extra: profile);

    // Always reload so the namecard reflects whatever was saved,
    // regardless of whether EditProfileScreen returned true/false/null.
    if (mounted) _loadProfile();
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await _authRepo.signOut();
      if (mounted) context.go(AppRoutes.login);
    } catch (_) {
      if (mounted) {
        setState(() => _signingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign out failed. Please try again.')),
        );
      }
    }
  }

  void _confirmSignOut() {
    _showActionConfirm(
      title: 'Sign out?',
      message: 'You\'ll need to sign back in to access your account.',
      confirmLabel: 'Sign out',
      onConfirm: _signOut,
    );
  }

  void _confirmDeleteAccount() {
    _showActionConfirm(
      title: 'Delete account?',
      message:
          'This will permanently delete your account, all your reviews, and your saved places. This action cannot be undone.',
      confirmLabel: 'Delete my account',
      onConfirm: _deleteAccount,
    );
  }

  void _showActionConfirm({
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onConfirm();
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                  side: BorderSide.none,
                ),
                child: Text(confirmLabel),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    try {
      await SupabaseClientProvider.client.rpc('delete_account');
      await _authRepo.signOut();
      if (mounted) context.go(AppRoutes.login);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete account. Please contact support.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: CustomScrollView(
            slivers: [
              _buildHeader(colorScheme),

              _buildSection(
                colorScheme,
                title: 'Your Activity',
                children: [
                  _SettingsTile(
                    icon: Icons.edit_outlined,
                    iconColor: colorScheme.primary,
                    title: 'Edit Profile',
                    subtitle: 'Update your name, photo, and interests',
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _loading ? null : _openEditProfile,
                  ),
                  _SettingsTile(
                    icon: Icons.rate_review_outlined,
                    iconColor: colorScheme.tertiary,
                    title: 'My Reviews',
                    subtitle: 'View and manage your reviews',
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.myReviews),
                  ),
                  _SettingsTile(
                    icon: Icons.campaign_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'My Requests',
                    subtitle: 'Track requests you posted to businesses',
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.myRequests),
                  ),
                  _SettingsTile(
                    icon: Icons.campaign_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Marketplace Requests',
                    subtitle: 'Requests you\'ve posted to local businesses',
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.myMarketplaceReqs),
                  ),
                  _SettingsTile(
                    icon: Icons.bookmark_outline_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Saved Places',
                    subtitle: 'Businesses you\'ve bookmarked',
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.saved),
                  ),
                ],
              ),

              if (!_loading && _isOwner)
                _buildSection(
                  colorScheme,
                  title: 'Business',
                  children: [
                    _SettingsTile(
                      icon: Icons.store_rounded,
                      iconColor: colorScheme.primary,
                      title: 'Owner Portal',
                      subtitle: 'Manage your business listings',
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(AppRoutes.ownerDashboard),
                    ),
                  ],
                ),

              if (_loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Container(
                      height: 68,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withAlpha(38),
                        ),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onSurface.withAlpha(77),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              _buildSection(
                colorScheme,
                title: 'Preferences',
                children: [
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Notifications',
                    subtitle: 'Manage what we send you',
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.notificationPrefs),
                  ),
                ],
              ),

              _buildSection(
                colorScheme,
                title: 'Account',
                children: [
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    iconColor: colorScheme.secondary,
                    title: 'Change Password',
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.resetPassword),
                  ),
                  _SettingsTile(
                    icon: Icons.delete_outline_rounded,
                    iconColor: colorScheme.error,
                    title: 'Delete Account',
                    onTap: _confirmDeleteAccount,
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    iconColor: colorScheme.error,
                    title: 'Sign Out',
                    onTap: _signingOut ? null : _confirmSignOut,
                    trailing: _signingOut
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.error,
                            ),
                          )
                        : null,
                  ),
                ],
              ),

              _buildAppVersion(colorScheme),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sliver builders ────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme colorScheme) {
    ImageProvider? avatarImage;
    if (_profile?.avatarUrl != null) {
      avatarImage = NetworkImage(_profile!.avatarUrl!);
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loading ? null : _openEditProfile,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.outline.withAlpha(38)),
                ),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              _initials,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (_profile?.username != null &&
                              _profile!.username != _displayName) ...[
                            const SizedBox(height: 1),
                            Text(
                              '@${_profile!.username}',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withAlpha(140),
                              ),
                            ),
                          ],
                          Text(
                            _email,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withAlpha(128),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!_loading) ...[
                            const SizedBox(height: 6),
                            _RoleBadge(isOwner: _isOwner),
                          ],
                        ],
                      ),
                    ),
                    // ← pencil icon removed
                  ],
                ),
              ),
            ),

            if (_profile != null && _profile!.interests.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _profile!.interests.map((id) {
                  final label = _interestLabel(id);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withAlpha(128),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    ColorScheme colorScheme, {
    required String title,
    required List<Widget> children,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: colorScheme.onSurface.withAlpha(128),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outline.withAlpha(38)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      Divider(
                        height: 1,
                        indent: 54,
                        color: colorScheme.outline.withAlpha(38),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppVersion(ColorScheme colorScheme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Center(
          child: Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withAlpha(77),
            ),
          ),
        ),
      ),
    );
  }

  String _interestLabel(String id) {
    const labels = {
      'food': '🍽️ Food & Dining',
      'retail': '🛍️ Retail',
      'services': '🔧 Services',
      'health': '💪 Health',
      'entertainment': '🎭 Entertainment',
      'beauty': '💅 Beauty',
    };
    return labels[id] ?? id;
  }
}

// ============================================================================
// Role badge
// ============================================================================

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isOwner});
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isOwner ? colorScheme.primary : colorScheme.secondary;
    final label = isOwner ? 'Owner' : 'Member';
    final icon = isOwner ? Icons.store_rounded : Icons.person_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(64)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Settings tile
// ============================================================================

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDestructive = iconColor == colorScheme.error;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDestructive
                            ? colorScheme.error
                            : colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colorScheme.onSurface.withAlpha(115),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                IconTheme(
                  data: IconThemeData(
                    color: colorScheme.onSurface.withAlpha(77),
                    size: 20,
                  ),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
