import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../data/microsoft_auth_service.dart';
import '../models/auth_user.dart';

part 'auth_state.dart';

/// Owns the sign-in lifecycle. UI reads [AuthStatus] to decide whether to show
/// the login screen or the app, and the [AuthGate] swaps pages accordingly.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({MicrosoftAuthService? service})
      : _service = service ?? MicrosoftAuthService(),
        super(const AuthState());

  final MicrosoftAuthService _service;

  Future<void> signIn() async {
    logAuth('signIn() requested');
    emit(state.copyWith(status: AuthStatus.signingIn, clearError: true));
    try {
      final user = await _service.signIn();
      _printLoginDetails(user);
      emit(state.copyWith(status: AuthStatus.signedIn, user: user));
    } on AuthException catch (e) {
      logError('AuthCubit.signIn', e);
      emit(state.copyWith(status: AuthStatus.signedOut, error: e.message));
    } catch (e, s) {
      logError('AuthCubit.signIn', e, s);
      emit(state.copyWith(
        status: AuthStatus.signedOut,
        error: 'Unexpected sign-in error: $e',
      ));
    }
  }

  /// Dev bypass: skip Microsoft sign-in and enter the app as a guest.
  void continueAsGuest() {
    logAuth('Continuing without sign-in (guest mode)');
    emit(state.copyWith(
      status: AuthStatus.signedIn,
      user: AuthUser.guest(),
      clearError: true,
    ));
  }

  void signOut() {
    logAuth('signOut()');
    emit(const AuthState());
  }

  /// Requirement: print all login details to the console after success.
  void _printLoginDetails(AuthUser user) {
    logAuth('Sign-in successful for ${user.name} <${user.email}>');
    for (final line in user.details.split('\n')) {
      logAuth(line);
    }
  }
}
