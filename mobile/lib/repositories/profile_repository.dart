import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/user_profile_model.dart';

class ProfileRepository {
  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<UserProfile?> getProfile() async {
    final user = SupabaseClientProvider.currentUser;
    if (user == null) return null;

    try {
      final data = await SupabaseClientProvider.client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return data != null ? UserProfile.fromJson(data) : null;
    } catch (e, st) {
      dev.log('ProfileRepository.getProfile error: $e', stackTrace: st);
      return null;
    }
  }

  // ── Save profile ──────────────────────────────────────────────────────────

  Future<void> saveProfile({
    required String username,
    String? fullName,
    String? city,
    File? avatarFile,
    List<String>? interests,
  }) async {
    final user = SupabaseClientProvider.currentUser;
    if (user == null) throw Exception('Not authenticated');

    String? avatarUrl;

    if (avatarFile != null) {
      try {
        final ext = avatarFile.path.split('.').last.toLowerCase();
        final path = '${user.id}/avatar.$ext';

        await SupabaseClientProvider.client.storage
            .from('avatars')
            .upload(
              path,
              avatarFile,
              fileOptions: const FileOptions(upsert: true),
            );

        avatarUrl = SupabaseClientProvider.client.storage
            .from('avatars')
            .getPublicUrl(path);
      } catch (e, st) {
        dev.log('Avatar upload failed (non-fatal): $e', stackTrace: st);
      }
    }

    // Always write full_name and city so that clearing them is persisted.
    // A null value in the map explicitly sets the column to NULL in Supabase.
    final updates = <String, dynamic>{
      'id': user.id,
      'username': username,
      'full_name': fullName?.trim().isEmpty == true ? null : fullName?.trim(),
      'city': city?.trim().isEmpty == true ? null : city?.trim(),
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (interests != null) 'interests': interests,
    };

    await SupabaseClientProvider.client.from('users').upsert(updates);
  }

  // ── Guest profile ─────────────────────────────────────────────────────────

  Future<void> createGuestProfile() async {
    const prefix = 'guest';
    const width = 7;
    const maxAttempts = 20;

    final existingProfile = await getProfile();
    final existingUsername = existingProfile?.username?.trim();
    if (existingUsername != null && existingUsername.isNotEmpty) {
      await completeOnboarding();
      return;
    }

    final random = Random.secure();
    final start = random.nextInt(10000000);

    for (var i = 0; i < maxAttempts; i++) {
      final candidate = (start + i) % 10000000;
      final guestNumber = candidate == 0 ? 1 : candidate;
      final username = '$prefix${guestNumber.toString().padLeft(width, '0')}';
      try {
        await saveProfile(username: username);
        await completeOnboarding();
        return;
      } catch (e, st) {
        if (_isUsernameConflict(e)) {
          dev.log('Guest username conflict for $username, retrying...',
              stackTrace: st);
          continue;
        }
        rethrow;
      }
    }

    throw Exception('Could not create a guest profile. Please try again.');
  }

  bool _isUsernameConflict(Object error) {
    if (error is! PostgrestException) return false;
    final msg = '${error.message} ${error.details ?? ''}'.toLowerCase();
    return msg.contains('username') &&
        (msg.contains('duplicate') || msg.contains('unique'));
  }

  // ── Complete onboarding ───────────────────────────────────────────────────

  Future<void> completeOnboarding() async {
    try {
      await SupabaseClientProvider.auth.updateUser(
        UserAttributes(data: {'onboarding_completed': true}),
      );
    } catch (e, st) {
      dev.log('completeOnboarding error: $e', stackTrace: st);
      rethrow;
    }
  }
}