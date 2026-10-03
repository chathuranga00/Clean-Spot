import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkNavigation();
  }

  Future<void> _checkNavigation() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final onboardingDone = ref.read(onboardingProvider);
    final authState = ref.read(authStateChangesProvider);

    authState.when(
      data: (user) {
        if (!onboardingDone) {
          context.go('/onboarding');
        } else if (user != null) {
          if (!user.isEmailVerified) {
            context.go('/verify-email');
          } else {
            context.go('/home');
          }
        } else {
          context.go('/login');
        }
      },
      loading: () {
        // Wait another moment if auth state is still resolving
        Future.delayed(const Duration(milliseconds: 500), _checkNavigation);
      },
      error: (_, _) {
        context.go('/login');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Dark Charcoal
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00897B),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 72,
                color: Color(0xFF00897B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'CleanSpot',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dengue Breeding Site Reporter',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFFB300),
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00897B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
