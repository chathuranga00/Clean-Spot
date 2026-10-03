import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_repository.dart';

/// Notifier to manage persistent onboarding completion state.
class OnboardingNotifier extends Notifier<bool> {
  static const _onboardingKey = 'cleanspot_onboarding_completed';

  @override
  bool build() {
    _loadState();
    return false;
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_onboardingKey) ?? false;
    } catch (_) {
      state = false;
    }
  }

  Future<void> completeOnboarding() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
    } catch (_) {}
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

/// State management controller for authentication actions using Riverpod 3 Notifier.
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<bool> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).signInWithEmailAndPassword(
            email: email,
            password: password,
          );
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    required String district,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).createUserWithEmailAndPassword(
            email: email,
            password: password,
            displayName: displayName,
            district: district,
          );
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> sendVerificationEmail() async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> reloadUser() async {
    await ref.read(authRepositoryProvider).reloadUser();
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
