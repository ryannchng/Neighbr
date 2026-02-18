import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/auth_state_notifier.dart';
import 'package:mobile/screens/auth/email_verification_screen.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'package:mobile/screens/auth/register_screen.dart';
import 'supabase_client.dart';

// ---------------------------------------------------------------------------
// Route name constants
// ---------------------------------------------------------------------------
abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const emailVerification = '/verify-email';
  static const home = '/home';
  static const businessList = '/businesses';
  static const businessDetail = '/businesses/:id';
  static const writeReview = '/businesses/:id/review';
  static const profile = '/profile';
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Drives GoRouter re-evaluation on every auth state change
  /// (sign-in, sign-out, token refresh, email verification, etc.)
  static final _authNotifier = AuthStateNotifier();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: _authNotifier,   // ← key change: reactive redirects
    redirect: _guard,
    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),

      // ── Auth screens ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return EmailVerificationScreen(email: email);
        },
      ),

      // ── Main app (bottom nav shell) ───────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) =>
                const _PlaceholderScreen(label: 'Home'),
          ),
          GoRoute(
            path: AppRoutes.businessList,
            builder: (context, state) =>
                const _PlaceholderScreen(label: 'Businesses'),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => _PlaceholderScreen(
                  label: 'Business ${state.pathParameters['id']}',
                ),
                routes: [
                  GoRoute(
                    path: 'review',
                    builder: (context, state) => _PlaceholderScreen(
                      label:
                          'Write Review for ${state.pathParameters['id']}',
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) =>
                const _PlaceholderScreen(label: 'Profile'),
          ),
        ],
      ),
    ],
  );

  // -------------------------------------------------------------------------
  // Guard
  // -------------------------------------------------------------------------
  static String? _guard(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final user = SupabaseClientProvider.currentUser;
    final isLoggedIn = user != null;
    final isEmailConfirmed = user?.emailConfirmedAt != null;

    final isOnSplash = loc == AppRoutes.splash;
    final isOnAuth = loc == AppRoutes.login ||
        loc == AppRoutes.register ||
        loc == AppRoutes.emailVerification;

    // Let splash handle its own logic
    if (isOnSplash) return null;

    // Not logged in → send to login
    if (!isLoggedIn && !isOnAuth) return AppRoutes.login;

    // Logged in but email not confirmed → hold on verification screen
    if (isLoggedIn && !isEmailConfirmed && loc != AppRoutes.emailVerification) {
      return '${AppRoutes.emailVerification}?email=${Uri.encodeComponent(user.email ?? '')}';
    }

    // Logged in & confirmed → push away from auth screens
    if (isLoggedIn && isEmailConfirmed && isOnAuth) {
      return AppRoutes.home;
    }

    return null;
  }
}

// ---------------------------------------------------------------------------
// App shell with bottom navigation bar
// ---------------------------------------------------------------------------
class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget child;

  static const _tabs = [
    (
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      route: AppRoutes.home,
    ),
    (
      icon: Icons.store_outlined,
      activeIcon: Icons.store,
      label: 'Browse',
      route: AppRoutes.businessList,
    ),
    (
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
      route: AppRoutes.profile,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final uri =
        GoRouter.of(context).routeInformationProvider.value.uri;
    final first = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (first == 'businesses') return 1;
    if (first == 'profile') return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => context.go(_tabs[i].route),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.activeIcon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Splash screen
// ---------------------------------------------------------------------------
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final user = SupabaseClientProvider.currentUser;
    if (user == null) {
      context.go(AppRoutes.login);
    } else if (user.emailConfirmedAt == null) {
      context.go(
        '${AppRoutes.emailVerification}?email=${Uri.encodeComponent(user.email ?? '')}',
      );
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder
// ---------------------------------------------------------------------------
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(child: Text(label)),
    );
  }
}