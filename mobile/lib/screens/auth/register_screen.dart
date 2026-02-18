import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router.dart';
import '../../repositories/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ─── State ────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authRepo = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  double _passwordStrength = 0;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _fadeController.forward();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Password strength ────────────────────────────────────────────────────
  void _updatePasswordStrength() {
    final p = _passwordController.text;
    double strength = 0;
    if (p.length >= 8) strength += 0.25;
    if (p.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (p.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength += 0.25;
    setState(() => _passwordStrength = strength);
  }

  Color _strengthColor() {
    if (_passwordStrength <= 0.25) return Colors.red;
    if (_passwordStrength <= 0.5) return Colors.orange;
    if (_passwordStrength <= 0.75) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _strengthLabel() {
    if (_passwordStrength <= 0.25) return 'Weak';
    if (_passwordStrength <= 0.5) return 'Fair';
    if (_passwordStrength <= 0.75) return 'Good';
    return 'Strong';
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authRepo.registerWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        username: _usernameController.text,
        // captchaToken: await _getCaptchaToken(), // plug in Turnstile here
      );

      if (mounted) {
        context.go(
          '${AppRoutes.emailVerification}?email=${Uri.encodeComponent(_emailController.text.trim())}',
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Validation ───────────────────────────────────────────────────────────
  String? _validateUsername(String? v) {
    if (v == null || v.trim().isEmpty) return 'Username is required.';
    if (v.trim().length < 3) return 'At least 3 characters.';
    if (v.trim().length > 30) return 'At most 30 characters.';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
      return 'Only letters, numbers and underscores.';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
      return 'Enter a valid email.';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'At least 8 characters required.';
    return null;
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: () => context.go(AppRoutes.login)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(colorScheme),
                      const SizedBox(height: 32),
                      _buildForm(colorScheme),
                      const SizedBox(height: 24),
                      _buildSubmitButton(colorScheme),
                      const SizedBox(height: 16),
                      _buildSignInCta(colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create account',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Discover and review local businesses',
          style: TextStyle(
            fontSize: 15,
            color: colorScheme.onSurface.withOpacity(0.55),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(ColorScheme colorScheme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            _ErrorBanner(message: _errorMessage!),
            const SizedBox(height: 20),
          ],

          // Username
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.name,
            autocorrect: false,
            validator: _validateUsername,
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'e.g. jane_smith',
              prefixIcon: Icon(Icons.alternate_email_rounded),
              helperText: 'Letters, numbers and underscores only',
            ),
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: _validateEmail,
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            validator: _validatePassword,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                tooltip:
                    _obscurePassword ? 'Show password' : 'Hide password',
              ),
            ),
          ),

          // Password strength indicator
          if (_passwordController.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _passwordStrength,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_strengthColor()),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _strengthLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    color: _strengthColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Terms notice
          Text(
            'By creating an account you agree to our Terms of Service and Privacy Policy.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(ColorScheme colorScheme) {
    return FilledButton(
      onPressed: _isLoading ? null : _submit,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      child: _isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.onPrimary,
              ),
            )
          : const Text('Create account'),
    );
  }

  Widget _buildSignInCta(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.login),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Sign in'),
        ),
      ],
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────────────────────
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
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}