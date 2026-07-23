/// Client-side retry and navigation hints for API error codes.
library;

import 'api_error.dart';

enum ErrorAction {
  retry,
  refreshAndRetry,
  reLogin,
  showMessage,
  reconnectWs,
}

ErrorAction actionFor(ApiErrorCode code, {required bool isWebSocket}) {
  if (code is CoreApiErrorCode) {
    switch (code.raw) {
      case 'token_expired':
        return isWebSocket ? ErrorAction.reconnectWs : ErrorAction.refreshAndRetry;
      case 'unauthorized':
      case 'invalid_token':
        return isWebSocket ? ErrorAction.reconnectWs : ErrorAction.reLogin;
      case 'forbidden':
        return ErrorAction.showMessage;
      case 'not_found':
        return ErrorAction.showMessage;
      case 'invalid_json':
      case 'invalid_message':
        return ErrorAction.showMessage;
      case 'not_implemented':
        return ErrorAction.showMessage;
      case 'rate_limited':
        return ErrorAction.showMessage;
      case 'internal_error':
        return isWebSocket ? ErrorAction.reconnectWs : ErrorAction.retry;
      default:
        return ErrorAction.showMessage;
    }
  }
  return ErrorAction.showMessage;
}

ErrorAction actionForApiError(ApiError error, {required bool isWebSocket}) =>
    actionFor(error.code, isWebSocket: isWebSocket);
