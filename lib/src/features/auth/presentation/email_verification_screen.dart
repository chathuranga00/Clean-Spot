import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  int _cooldownSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _resendEmail() async {
    final success =
        await ref.read(authControllerProvider.notifier).sendVerificationEmail();
    if (success && mounted) {
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification link resent. Please check your inbox.'),
          backgroundColor: Color(0xFF00897B),
        ),
      );
    }
  }

  Future<void> _checkVerification() async {
    await ref.read(authControllerProvider.notifier).reloadUser();
    if (!mounted) return;

    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null && user.isEmailVerified) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email has not been verified yet. Please tap the link sent to your inbox.',
          ),
          backgroundColor: Color(0xFFFFB300),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final email = user?.email ?? 'your email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64,
                    color: Color(0xFF00897B),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify Your Account',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to:\n$email\n\nPlease check your inbox and verify your email to unlock breeding site reporting.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  key: const Key('check_verification_button'),
                  onPressed: _checkVerification,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('I\'ve Verified My Email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('resend_verification_button'),
                  onPressed: _cooldownSeconds > 0 ? null : _resendEmail,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    _cooldownSeconds > 0
                        ? 'Resend Email in ${_cooldownSeconds}s'
                        : 'Resend Verification Email',
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  child: const Text('Log Out & Return to Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
