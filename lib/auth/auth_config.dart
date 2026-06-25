/// Microsoft Entra ID (Azure AD) configuration for sign-in.
///
/// Two modes, controlled by [restrictToCompany]:
///
///  • restrictToCompany = false  → ANY Microsoft account can sign in (work,
///    school, or personal). Authority is `common`. Only [clientId] is needed.
///  • restrictToCompany = true   → only members of one company directory can
///    sign in (single-tenant). Needs [clientId] AND [tenantId]; the `tid` claim
///    is verified in MicrosoftAuthService.
///
/// ──────────────────────────────────────────────────────────────────────────
/// SETUP (one-time, free — no paid subscription, no credit card):
///
/// You still need ONE app registration to get a Client ID. If you can't access
/// the company tenant, register in your OWN free tenant instead:
///
/// 1. Sign in to https://entra.microsoft.com (or portal.azure.com) with any
///    Microsoft account you control.
/// 2. Applications → App registrations → New registration.
///      • Name: "Academy Platform"
///      • Supported account types:
///          - For "any account" mode (restrictToCompany = false):
///            "Accounts in any organizational directory and personal Microsoft
///             accounts".
///          - For company-only mode (restrictToCompany = true):
///            "Accounts in this organizational directory only (Single tenant)".
///      • Redirect URI: platform "Mobile and desktop applications",
///        value `http://localhost` (Microsoft matches loopback on any port).
/// 3. Overview page → copy "Application (client) ID" into [clientId].
///    (Only copy "Directory (tenant) ID" into [tenantId] for company-only mode.)
/// 4. API permissions → Microsoft Graph → Delegated → `User.Read` (default).
/// ──────────────────────────────────────────────────────────────────────────
class AuthConfig {
  AuthConfig._();

  /// false → any Microsoft account may sign in. true → company members only.
  static const bool restrictToCompany = false;

  /// "Application (client) ID" GUID from the portal. Always required.
  static const String clientId = 'YOUR_CLIENT_ID';

  /// "Directory (tenant) ID" GUID — only used when [restrictToCompany] is true.
  static const String tenantId = 'YOUR_TENANT_ID';

  /// Authority: a specific tenant when locked to the company, otherwise
  /// `common` so any work/school/personal Microsoft account is accepted.
  static String get authority => restrictToCompany
      ? 'https://login.microsoftonline.com/$tenantId'
      : 'https://login.microsoftonline.com/common';

  static String get authorizeEndpoint => '$authority/oauth2/v2.0/authorize';

  static String get tokenEndpoint => '$authority/oauth2/v2.0/token';

  /// Scopes requested. `offline_access` yields a refresh token; `User.Read`
  /// lets us read the signed-in user's basic profile from Microsoft Graph.
  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
    'User.Read',
  ];

  /// True once the required placeholder(s) have been replaced with real GUIDs.
  static bool get isConfigured =>
      clientId != 'YOUR_CLIENT_ID' &&
      (!restrictToCompany || tenantId != 'YOUR_TENANT_ID');
}
