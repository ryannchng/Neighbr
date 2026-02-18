import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

/// A [ChangeNotifier] that mirrors Supabase auth state changes.
///
/// Plug this into [GoRouter.refreshListenable] so the router
/// automatically re-evaluates redirects whenever the user signs
/// in, signs out, or their token is refreshed.
///
/// Usage:
/// ```dart
/// static final _authNotifier = AuthStateNotifier();
///
/// static final router = GoRouter(
///   refreshListenable: _authNotifier,
///   redirect: _guard,
///   ...
/// );
/// ```
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier() {
    _subscription = SupabaseClientProvider.authStateChanges.listen(
      _onAuthStateChanged,
      onError: (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<AuthState> _subscription;

  /// The most recent auth event, useful for context-aware redirects.
  AuthChangeEvent? lastEvent;

  void _onAuthStateChanged(AuthState state) {
    lastEvent = state.event;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}