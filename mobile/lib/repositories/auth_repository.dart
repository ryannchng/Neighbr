import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

/// Thrown for all auth-related errors with a user-friendly message.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRepository {
  // ─── Sign in ──────────────────────────────────────────────────────────────

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseClientProvider.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.user == null) {
        throw const AuthException('Sign in failed. Please try again.');
      }
      return response;
    } on AuthApiException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
          'An unexpected error occurred. Please try again.');
    }
  }

  // ─── Register ─────────────────────────────────────────────────────────────

  /// [captchaToken] — pass the token from Cloudflare Turnstile / hCaptcha.
  /// Supabase will verify it server-side if CAPTCHA is enabled in your project.
  Future<AuthResponse> registerWithEmail({
    required String email,
    required String password,
    required String username,
    String? captchaToken,
  }) async {
    try {
      // 1. Ensure username is unique before creating the auth user.
      final existing = await SupabaseClientProvider.client
          .from('users')
          .select('id')
          .eq('username', username.trim())
          .maybeSingle();

      if (existing != null) {
        throw const AuthException('That username is already taken.');
      }

      // 2. Create the auth user. Supabase will send a verification email.
      final response = await SupabaseClientProvider.auth.signUp(
        email: email.trim(),
        password: password,
        // Pass CAPTCHA token if you have Turnstile / hCaptcha enabled
        // in Supabase Dashboard → Auth → Settings → Enable Captcha protection.
        captchaToken: captchaToken,
        data: {
          'username': username.trim(),   // stored in raw_user_meta_data
        },
      );

      if (response.user == null) {
        throw const AuthException('Registration failed. Please try again.');
      }

      // 3. Create the public profile row. Uses a DB trigger alternatively.
      //    Wrapping in try/catch so a DB hiccup doesn't orphan the auth user.
      try {
        await SupabaseClientProvider.client.from('users').upsert({
          'id': response.user!.id,
          'username': username.trim(),
        });
      } catch (_) {
        // Non-fatal: the trigger or a later sync can handle this.
      }

      return response;
    } on AuthApiException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
          'An unexpected error occurred. Please try again.');
    }
  }

  // ─── Password reset ───────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await SupabaseClientProvider.auth.resetPasswordForEmail(email.trim());
    } on AuthApiException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (_) {
      throw const AuthException(
          'Could not send reset email. Please try again.');
    }
  }

  // ─── Resend verification email ────────────────────────────────────────────

  Future<void> resendVerificationEmail(String email) async {
    try {
      await SupabaseClientProvider.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
    } on AuthApiException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (_) {
      throw const AuthException(
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