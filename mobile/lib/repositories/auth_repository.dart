import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../core/supabase_client.dart';

/// Thrown for all auth-related errors with a user-friendly message.
///
/// Named [AppAuthException] to avoid colliding with Supabase's own
/// [sb.AuthException].
class AppAuthException implements Exception {
  const AppAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRepository {
  // ─── Sign in ──────────────────────────────────────────────────────────────

  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseClientProvider.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.user == null) {
        throw const AppAuthException('Sign in failed. Please try again.');
      }
      return response;
    } on sb.AuthException catch (e, st) {
      dev.log('Supabase AuthException: ${e.message}', error: e, stackTrace: st);
      throw AppAuthException(_mapAuthError(e.message));
    } catch (e, st) {
      if (e is AppAuthException) rethrow;
      dev.log('Unexpected sign-in error: $e', error: e, stackTrace: st);
      throw AppAuthException(
          'An unexpected error occurred ($e). Please try again.');
    }
  }

  // ─── Register ─────────────────────────────────────────────────────────────

  Future<sb.AuthResponse> registerWithEmail({
    required String email,
    required String password,
    required String username,
    String? captchaToken,
  }) async {
    try {
      final existing = await SupabaseClientProvider.client
          .from('users')
          .select('id')
          .eq('username', username.trim())
          .maybeSingle();

      if (existing != null) {
        throw const AppAuthException('That username is already taken.');
      }

      final response = await SupabaseClientProvider.auth.signUp(
        email: email.trim(),
        password: password,
        captchaToken: captchaToken,
        data: {'username': username.trim()},
        emailRedirectTo: 'com.example.mobile://login-callback',
      );

      if (response.user == null) {
        throw const AppAuthException('Registration failed. Please try again.');
      }

      try {
        await SupabaseClientProvider.client.from('users').upsert({
          'id': response.user!.id,
          'username': username.trim(),
        });
      } catch (e) {
        dev.log('Non-fatal: could not upsert user profile row: $e');
      }

      return response;
    } on sb.AuthException catch (e, st) {
      dev.log('Supabase AuthException: ${e.message}', error: e, stackTrace: st);
      throw AppAuthException(_mapAuthError(e.message));
    } catch (e, st) {
      if (e is AppAuthException) rethrow;
      dev.log('Unexpected register error: $e', error: e, stackTrace: st);
      throw AppAuthException(
          'An unexpected error occurred ($e). Please try again.');
    }
  }

  // ─── Password reset ───────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await SupabaseClientProvider.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'com.example.mobile://login-callback',
      );
    } on sb.AuthException catch (e, st) {
      dev.log('Supabase AuthException: ${e.message}', error: e, stackTrace: st);
      throw AppAuthException(_mapAuthError(e.message));
    } catch (e, st) {
      dev.log('Unexpected password reset error: $e', error: e, stackTrace: st);
      throw const AppAuthException(
          'Could not send reset email. Please try again.');
    }
  }

  // ─── Resend verification email ────────────────────────────────────────────

  Future<void> resendVerificationEmail(String email) async {
    try {
      await SupabaseClientProvider.auth.resend(
        type: sb.OtpType.signup,
        email: email.trim(),
        emailRedirectTo: 'com.example.mobile://login-callback',
      );
    } on sb.AuthException catch (e, st) {
      dev.log('Supabase AuthException: ${e.message}', error: e, stackTrace: st);
      throw AppAuthException(_mapAuthError(e.message));
    } catch (e, st) {
      dev.log('Unexpected resend error: $e', error: e, stackTrace: st);
      throw const AppAuthException(
          'Could not resend verification email. Please try again.');
    }
  }

  // ─── Sign out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await SupabaseClientProvider.auth.signOut();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _mapAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (msg.contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('captcha')) {
      return 'Bot check failed. Please try again.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Network error. Check your connection and try again.';
    }
    return raw;
  }
}