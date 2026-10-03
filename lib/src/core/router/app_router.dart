import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final onboardingDone = ref.watch(onboardingProvider);

  return GoRouter(
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
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/report/new',
        builder: (context, state) => const NewReportScreen(),
      ),
      GoRoute(
        path: '/report/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'unknown';
          return ReportDetailScreen(reportId: id);
        },
      ),
      GoRoute(
        path: '/my-reports',
        builder: (context, state) => const MyReportsScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/education',
        builder: (context, state) => const EducationalScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/admin/review',
        builder: (context, state) => const AdminReviewScreen(),
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
