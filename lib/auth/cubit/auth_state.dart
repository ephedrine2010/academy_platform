part of 'auth_cubit.dart';

enum AuthStatus { signedOut, signingIn, signedIn }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.signedOut,
    this.user,
    this.error,
  });

  final AuthStatus status;
  final AuthUser? user;
  final String? error;

  bool get isSignedIn => status == AuthStatus.signedIn && user != null;
  bool get isBusy => status == AuthStatus.signingIn;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, user, error];
}
