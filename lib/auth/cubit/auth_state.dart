part of 'auth_cubit.dart';

enum AuthStatus { signedOut, signingIn, signedIn }

/// Coarse permission level resolved after sign-in. [admin] is granted when the
/// signed-in email has a matching doc in the `admins` Firestore collection
/// (populated by hand for the POC); everyone else is a [trainee].
enum AppRole { admin, trainee }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.signedOut,
    this.user,
    this.role = AppRole.trainee,
    this.error,
  });

  final AuthStatus status;
  final AuthUser? user;
  final AppRole role;
  final String? error;

  bool get isSignedIn => status == AuthStatus.signedIn && user != null;
  bool get isAdmin => role == AppRole.admin;
  bool get isBusy => status == AuthStatus.signingIn;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    AppRole? role,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      role: role ?? this.role,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, user, role, error];
}
