import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/auth_error_messages.dart';
import '../../core/http/auth_api_client.dart';
import '../../core/http/contracts/auth_api_contract.dart';
import '../../core/navigation/app_paths.dart';

/// Feedback after a verify deep link (SnackBar on Account / root).
final ValueNotifier<String?> emailVerifyDeepLinkMessage = ValueNotifier(null);

/// Captures `/wf-template-verify-email?token=` (HTTPS App Link or custom scheme).
///
/// Mirrors Dutch referral deep-link capture: fire-and-forget from go_router
/// redirect; no dedicated verify screen.
class EmailVerifyDeepLinkHandler {
  EmailVerifyDeepLinkHandler._();

  static AuthApiContract Function() _apiFactory = AuthApiClient.new;
  static Future<void> Function()? _onVerified;
  static String? _pendingToken;

  /// Wire from [AppBootstrap] so profile refresh uses Riverpod.
  static void bind({
    AuthApiContract Function()? apiFactory,
    Future<void> Function()? onVerified,
  }) {
    if (apiFactory != null) _apiFactory = apiFactory;
    _onVerified = onVerified;
    final pending = _pendingToken;
    if (pending != null && pending.isNotEmpty) {
      _pendingToken = null;
      onToken(pending);
    }
  }

  static void resetForTests() {
    _apiFactory = AuthApiClient.new;
    _onVerified = null;
    _pendingToken = null;
    emailVerifyDeepLinkMessage.value = null;
  }

  static void onToken(String rawToken) {
    final token = rawToken.trim();
    if (token.isEmpty) return;
    unawaited(_verify(token));
  }

  /// Capture before [bind] if needed; [bind] flushes [_pendingToken].
  static void onTokenDeferred(String rawToken) {
    final token = rawToken.trim();
    if (token.isEmpty) return;
    _pendingToken = token;
  }

  /// Extract token from HTTPS or `arcori://` verify URIs.
  static String? tokenFromUri(Uri uri) {
    final token = uri.queryParameters['token']?.trim() ?? '';
    if (token.isEmpty) return null;

    if (uri.scheme == 'arcori') {
      final host = uri.host.toLowerCase();
      if (host == 'wf-template-verify-email') return token;
      if (uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first.toLowerCase() ==
              'wf-template-verify-email') {
        return token;
      }
      return null;
    }

    final path = uri.path;
    if (path == AppPaths.verifyEmail || path.endsWith(AppPaths.verifyEmail)) {
      return token;
    }
    return null;
  }

  static Future<void> _verify(String token) async {
    final outcome = await _apiFactory().verifyEmail(token: token);
    if (!outcome.isSuccess) {
      emailVerifyDeepLinkMessage.value = userMessageForAuthFailure(
        apiError: outcome.error,
        isNetworkError: outcome.isNetworkError,
      );
      return;
    }
    emailVerifyDeepLinkMessage.value = 'Email verified successfully.';
    final refresh = _onVerified;
    if (refresh != null) {
      await refresh();
    }
  }
}
