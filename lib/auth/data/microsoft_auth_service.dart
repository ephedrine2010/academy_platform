import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../academy/utils/log.dart';
import '../auth_config.dart';
import '../models/auth_user.dart';

/// Raised when sign-in cannot complete. [message] is safe to show to the user.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Drives the Microsoft Entra ID sign-in for a Windows desktop app using the
/// OAuth2 **Authorization Code flow with PKCE**:
///
///   1. Spin up a loopback HTTP server on a random local port.
///   2. Open the system browser at the Microsoft authorize endpoint.
///   3. The user signs in; Microsoft redirects back to the loopback with a
///      one-time `code`.
///   4. Exchange the code (+ PKCE verifier) for tokens at the token endpoint.
///   5. Decode the ID token to read the employee's profile claims.
///
/// This is exactly what MSAL does internally — done directly here because
/// MSAL has no solid Flutter/Windows-desktop support, and the project already
/// relies on the loopback-server pattern (see ScormAssetServer).
class MicrosoftAuthService {
  static const Duration _timeout = Duration(minutes: 5);

  Future<AuthUser> signIn() async {
    if (!AuthConfig.isConfigured) {
      throw AuthException(
        'Microsoft sign-in is not configured yet. Add the company Client ID '
        'and Tenant ID in lib/auth/auth_config.dart.',
      );
    }

    final verifier = _randomUrlSafe(64);
    final challenge = _sha256Challenge(verifier);
    final state = _randomUrlSafe(24);

    // Bind first so we know which port to put in the redirect URI.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://localhost:${server.port}';
    logAuth('Loopback listening on $redirectUri');

    try {
      final authUrl = Uri.parse(AuthConfig.authorizeEndpoint).replace(
        queryParameters: {
          'client_id': AuthConfig.clientId,
          'response_type': 'code',
          'redirect_uri': redirectUri,
          'response_mode': 'query',
          'scope': AuthConfig.scopes.join(' '),
          'state': state,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          // Always let the user pick the account (avoids silent SSO surprises).
          'prompt': 'select_account',
        },
      );

      logAuth('Opening system browser for Microsoft sign-in…');
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw AuthException('Could not open the system browser for sign-in.');
      }

      final code = await _awaitRedirect(server, state);
      logAuth('Authorization code received, exchanging for tokens…');
      final tokens = await _exchangeCode(code, verifier, redirectUri);
      final user = _userFromIdToken(tokens);
      _verifyCompany(user);
      return user;
    } finally {
      await server.close(force: true);
    }
  }

  /// Waits for the browser to hit the loopback redirect, validates `state`,
  /// shows a friendly page in the browser, and returns the `code`.
  Future<String> _awaitRedirect(HttpServer server, String state) async {
    final completer = Completer<String>();

    final sub = server.listen((HttpRequest request) async {
      final params = request.uri.queryParameters;
      final error = params['error'];
      final code = params['code'];
      final returnedState = params['state'];

      String pageTitle;
      String pageBody;
      if (error != null) {
        pageTitle = 'Sign-in failed';
        pageBody = (params['error_description'] ?? error).toString();
        if (!completer.isCompleted) {
          completer.completeError(
            AuthException('Microsoft returned an error: $pageBody'),
          );
        }
      } else if (returnedState != state) {
        pageTitle = 'Sign-in failed';
        pageBody = 'State mismatch — request rejected for safety.';
        if (!completer.isCompleted) {
          completer.completeError(AuthException(pageBody));
        }
      } else if (code == null) {
        pageTitle = 'Sign-in failed';
        pageBody = 'No authorization code was returned.';
        if (!completer.isCompleted) {
          completer.completeError(AuthException(pageBody));
        }
      } else {
        pageTitle = 'Signed in';
        pageBody = 'You can close this tab and return to Academy Platform.';
        if (!completer.isCompleted) completer.complete(code);
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_browserPage(pageTitle, pageBody));
      await request.response.close();
    });

    try {
      return await completer.future.timeout(
        _timeout,
        onTimeout: () =>
            throw AuthException('Sign-in timed out — no response received.'),
      );
    } finally {
      await sub.cancel();
    }
  }

  Future<Map<String, dynamic>> _exchangeCode(
    String code,
    String verifier,
    String redirectUri,
  ) async {
    final response = await http.post(
      Uri.parse(AuthConfig.tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': AuthConfig.clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': verifier,
        'scope': AuthConfig.scopes.join(' '),
      },
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final desc = json['error_description'] ?? json['error'] ?? response.body;
      throw AuthException('Token exchange failed: $desc');
    }
    return json;
  }

  AuthUser _userFromIdToken(Map<String, dynamic> tokens) {
    final idToken = tokens['id_token'] as String?;
    if (idToken == null) {
      throw AuthException('No ID token was returned by Microsoft.');
    }
    final claims = _decodeJwtPayload(idToken);

    return AuthUser(
      id: (claims['oid'] ?? claims['sub'] ?? '').toString(),
      name: (claims['name'] ?? 'Unknown user').toString(),
      email: (claims['preferred_username'] ?? claims['email'] ?? '').toString(),
      tenantId: (claims['tid'] ?? '').toString(),
      claims: claims,
      accessToken: (tokens['access_token'] ?? '').toString(),
    );
  }

  /// In company-only mode, confirms the signed-in user really belongs to the
  /// target company directory and is a member (not an invited guest). When
  /// [AuthConfig.restrictToCompany] is false, any Microsoft account is allowed.
  void _verifyCompany(AuthUser user) {
    if (!AuthConfig.restrictToCompany) return;

    if (user.tenantId != AuthConfig.tenantId) {
      throw AuthException(
        'This account is not part of the company directory.',
      );
    }
    // `acct`: 0 = member, 1 = guest. Only present if added as an optional
    // claim in Azure; when absent we rely on the single-tenant restriction.
    final acct = user.claims['acct'];
    if (acct != null && acct.toString() != '0') {
      throw AuthException(
        'Guest accounts are not allowed — company employees only.',
      );
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _randomUrlSafe(int bytes) {
    final rnd = Random.secure();
    final values = List<int>.generate(bytes, (_) => rnd.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _sha256Challenge(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  Map<String, dynamic> _decodeJwtPayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) throw AuthException('Malformed ID token.');
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    switch (payload.length % 4) {
      case 2:
        payload += '==';
        break;
      case 3:
        payload += '=';
        break;
    }
    final decoded = utf8.decode(base64.decode(payload));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  String _browserPage(String title, String body) => '''
<!doctype html><html><head><meta charset="utf-8"><title>$title</title>
<style>
  body{font-family:Segoe UI,Arial,sans-serif;background:#f3f2f1;color:#201f1e;
       display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
  .card{background:#fff;padding:40px 48px;border-radius:8px;
        box-shadow:0 2px 8px rgba(0,0,0,.12);text-align:center;max-width:420px}
  h1{font-size:20px;margin:0 0 12px}p{margin:0;color:#605e5c}
</style></head><body>
  <div class="card"><h1>$title</h1><p>$body</p></div>
</body></html>''';
}
