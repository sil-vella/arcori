/// Authenticated user context after JWT verification.
library;

class AuthContext {
  const AuthContext({
    required this.userId,
    required this.claims,
  });

  final String userId;
  final Map<String, dynamic> claims;
}

/// [Request.context] key for the authenticated user id.
const authUserIdContextKey = 'wf_auth_user_id';

/// [Request.context] key for full JWT claims.
const authClaimsContextKey = 'wf_auth_claims';
