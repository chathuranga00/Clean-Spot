import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/scaffold_with_bottom_nav.dart';
import '../../features/admin/presentation/admin_review_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/education/presentation/educational_screen.dart';
import '../../features/gamification/presentation/leaderboard_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reports/presentation/home_screen.dart';
import '../../features/reports/presentation/my_reports_screen.dart';
import '../../features/reports/presentation/new_report_screen.dart';
import '../../features/reports/presentation/report_detail_screen.dart';
import '../../features/reports/presentation/report_review_screen.dart';
import '../../features/rewards/presentation/redemption_history_screen.dart';
import '../../features/rewards/presentation/reward_shop_screen.dart';
import '../../features/notifications/presentation/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>();
final _mapNavigatorKey = GlobalKey<NavigatorState>();
final _reportNavigatorKey = GlobalKey<NavigatorState>();
final _rewardsNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final onboardingDone = ref.watch(onboardingProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final loc = state.uri.path;
      final isSplash = loc == '/splash';
      final isOnboarding = loc == '/onboarding';
      final isLogin = loc == '/login';
      final isRegister = loc == '/register';
      final isForgotPassword = loc == '/forgot-password';
      final isAuthFlow = isLogin || isRegister || isForgotPassword;

      // Allow splash to perform initial resolution
      if (isSplash) return null;

      // If onboarding is not completed, direct to onboarding
      if (!onboardingDone) {
        return isOnboarding ? null : '/onboarding';
      }

      // If auth state is still resolving, do not interrupt
      if (authState.isLoading) return null;

      final user = authState.value;

      // Unauthenticated users
      if (user == null) {
        if (isAuthFlow || isOnboarding) {
          return null;
        }
        return '/login';
      }

      // Authenticated users with unverified email
      if (!user.isEmailVerified && loc != '/verify-email') {
        return '/verify-email';
      }

      // Authenticated users with verified email trying to hit auth flows
      if (user.isEmailVerified && (isAuthFlow || isOnboarding || loc == '/verify-email')) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Top-level Auth and Onboarding routes
      GoRoute(
        path: '/splash',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EmailVerificationScreen(),
      ),

      // Bottom Navigation Shell for Main App Sections
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithBottomNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home Dashboard
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Branch 1: Map
          StatefulShellBranch(
            navigatorKey: _mapNavigatorKey,
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          // Branch 2: Report Spot
          StatefulShellBranch(
            navigatorKey: _reportNavigatorKey,
            routes: [
              GoRoute(
                path: '/report/new',
                builder: (context, state) => const NewReportScreen(),
              ),
            ],
          ),
          // Branch 3: Rewards / Leaderboard
          StatefulShellBranch(
            navigatorKey: _rewardsNavigatorKey,
            routes: [
              GoRoute(
                path: '/leaderboard',
                builder: (context, state) => const LeaderboardScreen(),
              ),
            ],
          ),
          // Branch 4: Profile
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Sub-routes outside Bottom Nav
      GoRoute(
        path: '/report/review',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportReviewScreen(),
      ),
      GoRoute(
        path: '/report/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'unknown';
          return ReportDetailScreen(reportId: id);
        },
      ),
      GoRoute(
        path: '/my-reports',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyReportsScreen(),
      ),
      GoRoute(
        path: '/education',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EducationalScreen(),
      ),
      GoRoute(
        path: '/rewards',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RewardShopScreen(),
      ),
      GoRoute(
        path: '/redemptions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RedemptionHistoryScreen(),
      ),
      GoRoute(
        path: '/admin/review',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminReviewScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Text('No route defined for ${state.uri.toString()}'),
      ),
    ),
  );
});
