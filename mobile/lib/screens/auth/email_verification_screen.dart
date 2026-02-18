import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router.dart';
import '../../repositories/auth_repository.dart';

/// Shown immediately after a user registers.
///
/// The user lands here and is asked to check their inbox.
/// When they click the verification link, Supabase redirects back
/// to the app (via deep link / universal link). The [AuthStateNotifier]
/// picks up the SIGNED_IN / USER_UPDATED event and GoRouter's guard
/// redirects them to [AppRoutes.home] automatically — no action needed
/// in this screen beyond waiting.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});

  final String email;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _authRepo = AuthRepository();

  bool _resending = false;
  bool _resentRecently = false;
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  Future<void> _resend() async {
    if (_resentRecently) return;

    setState(() {
      _resending = true;
      _feedbackMessage = null;
    });

    try {
      await _authRepo.resendVerificationEmail(widget.email);
      setState(() {
        _resentRecently = true;
        _feedbackMessage = 'Verification email sent — check your inbox.';
        _feedbackIsError = false;
      });

      // Prevent spam: re-enable after 60 seconds
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted) setState(() => _resentRecently = false);
      });
    } on AuthException catch (e) {
      setState(() {
        _feedbackMessage = e.message;
        _feedbackIsError = true;
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _signOut() async {
    await _authRepo.signOut();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_unread_rounded,
                      size: 40,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Title
                  Text(
                    'Verify your email',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Body text
                  Text(
                    "We sent a verification link to",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Click the link in the email to activate your account. Once verified, you'll be signed in automatically.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.55),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Feedback banner
                  if (_feedbackMessage != null) ...[
                    _FeedbackBanner(
                      message: _feedbackMessage!,
                      isError: _feedbackIsError,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Resend button
                  FilledButton.tonal(
                    onPressed: _resending || _resentRecently ? null : _resend,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _resending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(
                            _resentRecently
                                ? 'Email sent ✓'
                                : 'Resend verification email',
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Sign out / use different account
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Use a different account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Feedback Banner ──────────────────────────────────────────────────────────
class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = isError ? colorScheme.errorContainer : colorScheme.primaryContainer;
    final fg = isError ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer;
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fg, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}