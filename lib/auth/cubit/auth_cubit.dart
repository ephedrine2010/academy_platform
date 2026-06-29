import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../data/microsoft_auth_service.dart';
import '../models/auth_user.dart';

part 'auth_state.dart';

/// Owns the sign-in lifecycle. The active path is Firebase email/password
/// ([signInWithEmail]); the Microsoft/Entra path ([signInWithMicrosoft]) is
/// kept dormant for when the company tenant is turned on. After a successful
/// sign-in the user's role is resolved from the `admins` collection so the UI
/// can decide whether to show the admin tabs.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    MicrosoftAuthService? microsoftService,
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _microsoft = microsoftService ?? MicrosoftAuthService(),
        _auth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        super(const AuthState());

  final MicrosoftAuthService _microsoft;
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Active sign-in path: Firebase email + password.
  Future<void> signInWithEmail(String email, String password) async {
    final trimmed = email.trim();
    logAuth('signInWithEmail($trimmed) requested');
    emit(state.copyWith(status: AuthStatus.signingIn, clearError: true));
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: trimmed,
        password: password,
      );
      final fbUser = cred.user!;
      final user = AuthUser.fromFirebase(
        id: fbUser.uid,
        name: (fbUser.displayName?.isNotEmpty ?? false)
            ? fbUser.displayName!
            : (fbUser.email ?? trimmed),
        email: fbUser.email ?? trimmed,
      );
      final role = await _resolveRole(user.email);
      _printLoginDetails(user, role);
      emit(state.copyWith(status: AuthStatus.signedIn, user: user, role: role));
      
    } on fb.FirebaseAuthException catch (e) {
      logError('AuthCubit.signInWithEmail', e);
      emit(state.copyWith(status: AuthStatus.signedOut, error: _friendly(e)));
    } catch (e, s) {
      logError('AuthCubit.signInWithEmail', e, s);
      emit(state.copyWith(
        status: AuthStatus.signedOut,
        error: 'Unexpected sign-in error: $e',
      ));
    }
  }

  /// Dormant path, kept for when Microsoft/Entra is enabled for the company.
  Future<void> signInWithMicrosoft() async {
    logAuth('signInWithMicrosoft() requested');
    emit(state.copyWith(status: AuthStatus.signingIn, clearError: true));
    try {
      final user = await _microsoft.signIn();
      final role = await _resolveRole(user.email);
      _printLoginDetails(user, role);
      emit(state.copyWith(status: AuthStatus.signedIn, user: user, role: role));
    } on AuthException catch (e) {
      logError('AuthCubit.signInWithMicrosoft', e);
      emit(state.copyWith(status: AuthStatus.signedOut, error: e.message));
    } catch (e, s) {
      logError('AuthCubit.signInWithMicrosoft', e, s);
      emit(state.copyWith(
        status: AuthStatus.signedOut,
        error: 'Unexpected sign-in error: $e',
      ));
    }
  }

  /// Dev bypass: skip sign-in and enter the app as a (trainee) guest.
  void continueAsGuest() {
    logAuth('Continuing without sign-in (guest mode)');
    emit(state.copyWith(
      status: AuthStatus.signedIn,
      user: AuthUser.guest(),
      role: AppRole.trainee,
      clearError: true,
    ));
  }

  Future<void> signOut() async {
    logAuth('signOut()');
    try {
      await _auth.signOut();
    } catch (e, s) {
      logError('AuthCubit.signOut', e, s);
    }
    emit(const AuthState());
  }

  /// Resolves the role from the matching `admins` doc's `role` field
  /// (`admin01` → manager, `admin02` → instructor). No matching doc — or any
  /// unrecognised value — means a plain [AppRole.trainee]. The admin docs are
  /// created by hand in the Firebase console; the stored `email` must match the
  /// sign-in email exactly.
  Future<AppRole> _resolveRole(String email) async {
    final needle = email.trim().toLowerCase();
    try {
      logAuth('Resolving role for "$needle" from admins…');
      final snap = await _db
          .collection('admins')
          .where('email', isEqualTo: needle)
          .limit(1)
          .get();
      logAuth('admins query returned ${snap.docs.length} doc(s)');
      if (snap.docs.isNotEmpty) {
        final raw = snap.docs.first.data()['role'];
        final role = AppRole.fromAdminRole(raw as String?);
        logAuth('Role field = "$raw" → ${role.name}');
        return role;
      }
    } catch (e, s) {
      // Most often a Firestore permission-denied (security rules blocking the
      // read) — that lands here and would otherwise look like "just a trainee".
      logError('AuthCubit._resolveRole (read failed — check Firestore rules)',
          e, s);
    }
    logAuth('No matching admin doc — role resolved: trainee');
    return AppRole.trainee;
  }

  String _friendly(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error — check your connection.';
      default:
        return e.message ?? 'Sign-in failed (${e.code}).';
    }
  }

  void _printLoginDetails(AuthUser user, AppRole role) {
    logAuth('Sign-in successful for ${user.name} <${user.email}> as $role');
    for (final line in user.details.split('\n')) {
      logAuth(line);
    }
  }
}
