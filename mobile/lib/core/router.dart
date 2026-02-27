import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:neighbr/core/services/auth_state_notifier.dart';
import 'package:neighbr/models/business_model.dart';
import 'package:neighbr/models/user_profile_model.dart';
import 'package:neighbr/screens/marketplace/my_marketplace_requests_screen.dart';
import 'package:neighbr/screens/marketplace/write_marketplace_request_screen.dart';
import 'package:neighbr/screens/profile/edit_profile_screen.dart';
import 'package:neighbr/screens/profile/my_requests_screen.dart';
import 'package:neighbr/screens/profile/my_reviews_screen.dart';
import 'package:neighbr/screens/profile/saved_screen.dart';
import 'package:neighbr/screens/profile/notification_prefs_screen.dart';
import 'package:neighbr/screens/auth/email_verification_screen.dart';
import 'package:neighbr/screens/auth/login_screen.dart';
import 'package:neighbr/screens/auth/register_screen.dart';
import 'package:neighbr/screens/auth/reset_password_screen.dart';
import 'package:neighbr/screens/home/home_screen.dart';
import 'package:neighbr/screens/business/business_detail_screen.dart';
import 'package:neighbr/screens/business/write_review_screen.dart';
import 'package:neighbr/screens/owner/owner_dashboard_screen.dart';
import 'package:neighbr/screens/owner/owner_business_detail_screen.dart';
import 'package:neighbr/screens/owner/owner_business_form_screen.dart';
import 'package:neighbr/screens/profile/profile_screen.dart';
import 'package:neighbr/screens/onboarding/onboarding_screen.dart';
import 'package:neighbr/screens/browse/browse_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

// ---------------------------------------------------------------------------
// Route name constants
// ---------------------------------------------------------------------------
abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const emailVerification = '/verify-email';
  static const resetPassword = '/reset-password';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const businessList = '/businesses';
  static const businessDetail = '/businesses/:id';
  static const writeReview = '/businesses/:id/review';
  static const profile = '/profile';

  // Profile sub-routes
  static const editProfile = '/profile/edit';
  static const myReviews = '/profile/reviews';
  static const myRequests = '/profile/requests';
  static const saved = '/profile/saved';
  static const notificationPrefs = '/profile/notifications';

  // Owner portal
  static const ownerDashboard = '/owner';
  static const ownerBusinessForm = '/owner/businesses/new';
  static const ownerBusinessDetail = '/owner/businesses/:id';

  // Marketplace requests (customer)
  static const marketplaceNew = '/marketplace/new';
  static const myMarketplaceReqs = '/profile/marketplace-requests';
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Drives GoRouter re-evaluation on every auth state change.
  static final _authNotifier = AuthStateNotifier();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: _authNotifier,
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
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // ── Owner portal (outside shell — no bottom nav) ──────────────────────
      GoRoute(
        path: AppRoutes.ownerDashboard,
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerBusinessForm,
        builder: (context, state) {
          final business = state.extra as Business?;
          return OwnerBusinessFormScreen(business: business);
        },
      ),
      GoRoute(
        path: AppRoutes.ownerBusinessDetail,
        builder: (context, state) {
          final businessId = state.pathParameters['id']!;
          return OwnerBusinessDetailScreen(businessId: businessId);
        },
      ),

      // ── Onboarding ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ── Main app (bottom nav shell) ───────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessList,
            builder: (context, state) => const BrowseScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final businessId = state.pathParameters['id']!;
                  return BusinessDetailScreen(businessId: businessId);
                },
                routes: [
                  GoRoute(
                    path: 'review',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      final businessId = state.pathParameters['id']!;
                      final businessName =
                          extra?['businessName'] as String? ?? '';
                      return WriteReviewScreen(
                        businessId: businessId,
                        businessName: businessName,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final profile = state.extra as UserProfile;
                  return EditProfileScreen(profile: profile);
                },
              ),
              GoRoute(
                path: 'reviews',
                builder: (context, state) => const MyReviewsScreen(),
              ),
              GoRoute(
                path: 'requests',
                builder: (context, state) => const MyRequestsScreen(),
              ),
              GoRoute(
                path: 'saved',
                builder: (context, state) => const SavedScreen(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const NotificationPrefsScreen(),
              ),
              GoRoute(
                path: 'marketplace-requests',
                builder: (context, state) =>
                    const MyMarketplaceRequestsScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.marketplaceNew,
        builder: (context, state) => const WriteMarketplaceRequestScreen(),
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

    final lastEvent = _authNotifier.lastEvent;
    if (lastEvent == AuthChangeEvent.passwordRecovery) {
      if (loc != AppRoutes.resetPassword) return AppRoutes.resetPassword;
      return null;
    }

    final isEmailConfirmed =
        user?.emailConfirmedAt != null ||
        user?.userMetadata?['email_verified'] == true;

    final isAnonymous = user?.isAnonymous ?? false;

    final hasCompletedOnboarding =
        user?.userMetadata?['onboarding_completed'] == true;

    final isOnSplash = loc == AppRoutes.splash;
    final isOnAuth =
        loc == AppRoutes.login ||
        loc == AppRoutes.register ||
        loc == AppRoutes.emailVerification;
    final isOnOnboarding = loc == AppRoutes.onboarding;

    if (isOnSplash) return null;

    if (!isLoggedIn && !isOnAuth) return AppRoutes.login;

    if (isLoggedIn && isAnonymous && (isOnAuth || isOnOnboarding)) {
      return AppRoutes.home;
    }

    if (isLoggedIn &&
        !isAnonymous &&
        !isEmailConfirmed &&
        loc != AppRoutes.emailVerification) {
      return '${AppRoutes.emailVerification}'
          '?email=${Uri.encodeComponent(user.email ?? '')}';
    }

    if (isLoggedIn &&
        !isAnonymous &&
        isEmailConfirmed &&
        !hasCompletedOnboarding &&
        !isOnOnboarding) {
      return AppRoutes.onboarding;
    }

    if (isLoggedIn &&
        (isEmailConfirmed || isAnonymous) &&
        hasCompletedOnboarding) {
      if (isOnAuth || isOnOnboarding) return AppRoutes.home;
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
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Explore',
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
    final uri = GoRouter.of(context).routeInformationProvider.value.uri;
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
    } else if (user.isAnonymous) {
      context.go(AppRoutes.home);
    } else if (user.emailConfirmedAt == null) {
      context.go(
        '${AppRoutes.emailVerification}'
        '?email=${Uri.encodeComponent(user.email ?? '')}',
      );
    } else if (user.userMetadata?['onboarding_completed'] != true) {
      context.go(AppRoutes.onboarding);
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
