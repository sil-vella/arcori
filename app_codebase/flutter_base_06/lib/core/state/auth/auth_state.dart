/// Immutable auth session snapshot (tier 1 — core session).
enum SessionStatus {
  unknown,
  authenticated,
  unauthenticated,
}

class AuthState {
  const AuthState({
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.isGuest = false,
    this.sessionStatus = SessionStatus.unknown,
    this.isLoading = false,
    this.errorMessage,
  });

  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final bool isGuest;
  final SessionStatus sessionStatus;
  final bool isLoading;
  final String? errorMessage;

  bool get isBootstrapping => sessionStatus == SessionStatus.unknown;

  bool get isAuthenticated =>
      sessionStatus == SessionStatus.authenticated &&
      accessToken != null &&
      accessToken!.isNotEmpty;

  AuthState copyWith({
    String? accessToken,
    String? refreshToken,
    String? userId,
    bool? isGuest,
    SessionStatus? sessionStatus,
    bool? isLoading,
    String? errorMessage,
    bool clearTokens = false,
    bool clearError = false,
  }) {
    return AuthState(
      accessToken: clearTokens ? null : (accessToken ?? this.accessToken),
      refreshToken: clearTokens ? null : (refreshToken ?? this.refreshToken),
      userId: clearTokens ? null : (userId ?? this.userId),
      isGuest: clearTokens ? false : (isGuest ?? this.isGuest),
      sessionStatus: sessionStatus ?? this.sessionStatus,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
