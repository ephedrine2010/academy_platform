import 'package:equatable/equatable.dart';

/// The signed-in company employee, derived from the ID token claims returned by
/// Microsoft Entra ID. "Basic from token" — no Microsoft Graph call needed.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.tenantId = '—',
    this.claims = const {},
    this.accessToken = '',
  });

  /// Built from a Firebase email/password sign-in (the active auth path while
  /// Microsoft/Entra is disabled). Microsoft-specific fields stay empty.
  factory AuthUser.fromFirebase({
    required String id,
    required String name,
    required String email,
  }) =>
      AuthUser(
        id: id,
        name: name,
        email: email,
        claims: const {'provider': 'firebase / email-password'},
      );

  /// Stable user object id (`oid`, falls back to `sub`).
  final String id;

  /// Display name (`name` claim).
  final String name;

  /// Sign-in name / email (`preferred_username`, falls back to `email`).
  final String email;

  /// Directory the user belongs to (`tid` claim).
  final String tenantId;

  /// All raw ID-token claims, kept so the full login details can be printed.
  final Map<String, dynamic> claims;

  /// Graph access token (kept in-memory only for this POC session).
  final String accessToken;

  /// A stand-in user for the "continue without signing in" dev bypass.
  factory AuthUser.guest() => const AuthUser(
        id: 'guest',
        name: 'Guest (not signed in)',
        email: '—',
        tenantId: '—',
        claims: {'note': 'Signed-in skipped — running as guest.'},
        accessToken: '',
      );

  bool get isGuest => id == 'guest';

  /// Human-readable dump of every claim, for console + on-screen display.
  String get details {
    final buffer = StringBuffer()
      ..writeln('name      : $name')
      ..writeln('email     : $email')
      ..writeln('user id   : $id')
      ..writeln('tenant id : $tenantId');
    buffer.writeln('--- all id-token claims ---');
    for (final entry in claims.entries) {
      buffer.writeln('${entry.key} = ${entry.value}');
    }
    return buffer.toString().trimRight();
  }

  @override
  List<Object?> get props => [id, name, email, tenantId];
}
