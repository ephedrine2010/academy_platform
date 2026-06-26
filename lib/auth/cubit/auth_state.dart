part of 'auth_cubit.dart';

enum AuthStatus { signedOut, signingIn, signedIn }

/// Permission level resolved after sign-in from the `admins/{doc}.role` field.
///
/// - [manager] (`admin01`) — main manager: regions, trainers, courses, and
///   assigning courses to trainees.
/// - [trainer] (`admin02`) — trainer: creates courses and assigns them to
///   trainees.
/// - [trainee] — everyone else (no `admins` doc): the normal user.
enum AppRole {
  manager,
  trainer,
  trainee;

  /// Maps the stored `role` string on an `admins` doc to a role. Anything
  /// unrecognised (or absent) falls back to [trainee].
  static AppRole fromAdminRole(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'admin01':
        return AppRole.manager;
      case 'admin02':
        return AppRole.trainer;
      default:
        return AppRole.trainee;
    }
  }
}

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

  /// Any privileged role (manager or trainer) — i.e. sees the admin shell.
  bool get isAdmin => role == AppRole.manager || role == AppRole.trainer;
  bool get isManager => role == AppRole.manager;
  bool get isTrainer => role == AppRole.trainer;
  bool get isTrainee => role == AppRole.trainee;
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
