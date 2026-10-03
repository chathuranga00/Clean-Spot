import 'package:cleanspot/src/features/auth/data/auth_repository.dart';
import 'package:cleanspot/src/features/auth/domain/auth_user.dart';
import 'package:cleanspot/src/features/auth/presentation/forgot_password_screen.dart';
import 'package:cleanspot/src/features/auth/presentation/login_screen.dart';
import 'package:cleanspot/src/features/auth/presentation/onboarding_screen.dart';
import 'package:cleanspot/src/features/auth/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository implements AuthRepository {
  bool signInCalled = false;
  bool registerCalled = false;
  bool passwordResetCalled = false;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(null);

  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalled = true;
    return const AuthUser(
      uid: 'mock_123',
      email: 'citizen@example.com',
      displayName: 'Test Citizen',
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required String district,
  }) async {
    registerCalled = true;
    return const AuthUser(
      uid: 'mock_123',
      email: 'citizen@example.com',
      displayName: 'Test Citizen',
      isEmailVerified: false,
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    passwordResetCalled = true;
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> reloadUser() async {}

  @override
  Future<void> signOut() async {}
}

Widget createTestApp(Widget child, [MockAuthRepository? repo]) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => child),
      GoRoute(path: '/home', builder: (context, state) => const Scaffold(body: Text('Home Page'))),
      GoRoute(path: '/verify-email', builder: (context, state) => const Scaffold(body: Text('Verify Email Page'))),
      GoRoute(path: '/forgot-password', builder: (context, state) => const Scaffold(body: Text('Forgot Password Page'))),
      GoRoute(path: '/register', builder: (context, state) => const Scaffold(body: Text('Register Page'))),
      GoRoute(path: '/login', builder: (context, state) => const Scaffold(body: Text('Login Page'))),
    ],
  );

  return ProviderScope(
    overrides: [
      if (repo != null) authRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoginScreen Tests', () {
    testWidgets('Validates empty and invalid email and password', (tester) async {
      final mockRepo = MockAuthRepository();

      await tester.pumpWidget(createTestApp(const LoginScreen(), mockRepo));
      await tester.pumpAndSettle();

      // Tap submit with empty fields
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);

      // Enter invalid email and short password
      await tester.enterText(find.byKey(const Key('login_email_field')), 'invalid-email');
      await tester.enterText(find.byKey(const Key('login_password_field')), '123');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);

      // Enter valid credentials
      await tester.enterText(find.byKey(const Key('login_email_field')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'password123');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(mockRepo.signInCalled, isTrue);
      expect(find.text('Home Page'), findsOneWidget);
    });
  });

  group('RegisterScreen Tests', () {
    testWidgets('Validates name, password mismatch and valid registration', (tester) async {
      final mockRepo = MockAuthRepository();

      await tester.pumpWidget(createTestApp(const RegisterScreen(), mockRepo));
      await tester.pumpAndSettle();

      // Scroll to submit button and tap with empty fields
      final submitFinder = find.byKey(const Key('register_submit_button'));
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);

      // Enter mismatched passwords
      await tester.enterText(find.byKey(const Key('register_name_field')), 'Kamal Silva');
      await tester.enterText(find.byKey(const Key('register_email_field')), 'kamal@example.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'password123');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'mismatched123');

      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);

      // Fix confirm password
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'password123');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(mockRepo.registerCalled, isTrue);
      expect(find.text('Verify Email Page'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen Tests', () {
    testWidgets('Validates email field and calls password reset', (tester) async {
      final mockRepo = MockAuthRepository();

      await tester.pumpWidget(createTestApp(const ForgotPasswordScreen(), mockRepo));
      await tester.pumpAndSettle();

      // Tap submit with empty email
      await tester.tap(find.byKey(const Key('forgot_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);

      // Enter valid email
      await tester.enterText(find.byKey(const Key('forgot_email_field')), 'user@example.com');
      await tester.tap(find.byKey(const Key('forgot_submit_button')));
      await tester.pumpAndSettle();

      expect(mockRepo.passwordResetCalled, isTrue);
      expect(find.text('Password Reset Email Sent'), findsOneWidget);
    });
  });

  group('OnboardingScreen Tests', () {
    testWidgets('Navigates pages and advances on action button', (tester) async {
      await tester.pumpWidget(createTestApp(const OnboardingScreen()));
      await tester.pumpAndSettle();

      // Slide 1
      expect(find.text('Spot Breeding Hazards'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Advance to Slide 2
      await tester.tap(find.byKey(const Key('onboarding_action_button')));
      await tester.pumpAndSettle();

      expect(find.text('AI Hazard Verification'), findsOneWidget);

      // Advance to Slide 3
      await tester.tap(find.byKey(const Key('onboarding_action_button')));
      await tester.pumpAndSettle();

      expect(find.text('Protect & Earn Civic Points'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // Tap Get Started
      await tester.tap(find.byKey(const Key('onboarding_action_button')));
      await tester.pumpAndSettle();

      expect(find.text('Login Page'), findsOneWidget);
    });
  });
}
