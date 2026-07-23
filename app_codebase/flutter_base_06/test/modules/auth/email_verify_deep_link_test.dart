import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/errors/api_error.dart';
import 'package:arcori/core/http/contracts/auth_api_contract.dart';
import 'package:arcori/core/navigation/app_paths.dart';
import 'package:arcori/modules/auth/email_verify_deep_link.dart';

class _RecordingAuthApi implements AuthApiContract {
  String? lastToken;
  AuthApiOutcome<bool> outcome = const AuthApiOutcome.success(true);

  @override
  Future<AuthLoginResult?> devLogin(String userId) async => null;

  @override
  Future<AuthApiOutcome<AuthLoginResult>> register({
    required String username,
    required String email,
    required String password,
    bool isGuest = false,
  }) async =>
      const AuthApiOutcome.networkFailure();

  @override
  Future<AuthApiOutcome<AuthLoginResult>> login({
    required String email,
    required String password,
  }) async =>
      const AuthApiOutcome.networkFailure();

  @override
  Future<AuthRefreshResult?> refreshAccessToken(String refreshToken) async =>
      null;

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<AuthApiOutcome<bool>> deleteAccount({
    required String accessToken,
    required String password,
    required String confirmation,
  }) async =>
      const AuthApiOutcome.networkFailure();

  @override
  Future<AuthApiOutcome<AuthLoginResult>> convertGuestAccount({
    required String accessToken,
    required String guestEmail,
    required String username,
    required String email,
    required String password,
  }) async =>
      const AuthApiOutcome.networkFailure();

  @override
  Future<AuthApiOutcome<bool>> verifyEmail({required String token}) async {
    lastToken = token;
    return outcome;
  }
}

void main() {
  tearDown(EmailVerifyDeepLinkHandler.resetForTests);

  group('EmailVerifyDeepLinkHandler.tokenFromUri', () {
    test('parses HTTPS App Link path', () {
      final uri = Uri.parse(
        'https://your-domain.example${AppPaths.verifyEmail}?token=abc123',
      );
      expect(EmailVerifyDeepLinkHandler.tokenFromUri(uri), 'abc123');
    });

    test('parses custom scheme host', () {
      final uri = Uri.parse(
        'arcori://wf-template-verify-email?token=xyz',
      );
      expect(EmailVerifyDeepLinkHandler.tokenFromUri(uri), 'xyz');
    });

    test('rejects unrelated path', () {
      final uri = Uri.parse('https://your-domain.example/account?token=abc');
      expect(EmailVerifyDeepLinkHandler.tokenFromUri(uri), isNull);
    });

    test('rejects missing token', () {
      final uri = Uri.parse(
        'https://your-domain.example${AppPaths.verifyEmail}',
      );
      expect(EmailVerifyDeepLinkHandler.tokenFromUri(uri), isNull);
    });
  });

  group('EmailVerifyDeepLinkHandler.onToken', () {
    test('success sets feedback message and calls verify API', () async {
      final api = _RecordingAuthApi();
      var refreshed = false;
      EmailVerifyDeepLinkHandler.bind(
        apiFactory: () => api,
        onVerified: () async {
          refreshed = true;
        },
      );

      EmailVerifyDeepLinkHandler.onToken('tok-1');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(api.lastToken, 'tok-1');
      expect(emailVerifyDeepLinkMessage.value, 'Email verified successfully.');
      expect(refreshed, isTrue);
    });

    test('invalid token surfaces auth message', () async {
      final api = _RecordingAuthApi()
        ..outcome = AuthApiOutcome.failure(
          error: ApiError(
            code: ApiErrorCode.parse('auth/invalid_verification_token'),
            message: 'Invalid or expired verification token',
            rawCode: 'auth/invalid_verification_token',
          ),
        );
      EmailVerifyDeepLinkHandler.bind(apiFactory: () => api);

      EmailVerifyDeepLinkHandler.onToken('bad');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        emailVerifyDeepLinkMessage.value,
        contains('invalid or expired'),
      );
    });
  });
}
