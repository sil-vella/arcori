/// User-facing auth messages derived from [ApiError] and [error_policy].
library;

import 'api_error.dart';
import 'error_policy.dart';

String userMessageForAuthFailure({
  ApiError? apiError,
  bool isNetworkError = false,
}) {
  if (isNetworkError) {
    return 'Cannot reach the server. Check your connection and try again from Account.';
  }
  if (apiError != null) {
    if (apiError.rawCode == 'auth/invalid_verification_token') {
      return 'That verification link is invalid or expired. Request a new one.';
    }
    if (apiError.rawCode == 'auth/email_verify_forbidden') {
      return 'Guest accounts cannot verify email. Convert to a full account first.';
    }
    if (apiError.rawCode == 'auth/email_already_verified') {
      return 'Your email is already verified.';
    }
    if (apiError.code is CoreApiErrorCode &&
        apiError.code.raw == 'rate_limited') {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    final action = actionForApiError(apiError, isWebSocket: false);
    switch (action) {
      case ErrorAction.reLogin:
      case ErrorAction.showMessage:
        return apiError.message;
      case ErrorAction.retry:
        return '${apiError.message} Try again from Account.';
      case ErrorAction.refreshAndRetry:
        return apiError.message;
      case ErrorAction.reconnectWs:
        return apiError.message;
    }
  }
  return 'Sign-in failed. Try again from Account.';
}
