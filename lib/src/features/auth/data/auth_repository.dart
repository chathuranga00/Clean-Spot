import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_user.dart';

class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepository(this._firebaseAuth);

  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapFirebaseUser);
  }

  AuthUser? get currentUser => _mapFirebaseUser(_firebaseAuth.currentUser);

  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('User credentials could not be retrieved.');
      }
      return _mapFirebaseUser(user)!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e), code: e.code);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<AuthUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required String district,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('User account could not be created.');
      }

      // Update display name on auth profile
      await user.updateDisplayName(displayName.trim());

      // Send email verification
      await user.sendEmailVerification();

      return _mapFirebaseUser(user)!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e), code: e.code);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e), code: e.code);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException catch (e) {
        throw AuthException(_mapFirebaseError(e), code: e.code);
      }
    }
  }

  Future<void> reloadUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  AuthUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'Citizen',
      isEmailVerified: user.emailVerified,
      photoUrl: user.photoURL,
    );
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email address is already in use by another account.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'The password provided is too weak. Please use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      default:
        return e.message ?? 'An unexpected authentication error occurred.';
    }
  }
}

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

final authStateChangesProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
