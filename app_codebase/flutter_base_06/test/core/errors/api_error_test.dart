import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/errors/api_error.dart';
import 'package:arcori/core/errors/error_policy.dart';

void main() {
  test('ApiError parses wire envelope', () {
    final err = ApiError.fromEnvelope({
      'ok': false,
      'error': {'code': 'token_expired', 'message': 'Access token expired'},
    });
    expect(err.rawCode, 'token_expired');
    expect(err.code, CoreApiErrorCode.tokenExpired);
    expect(err.message, 'Access token expired');
  });

  test('module code stays opaque', () {
    final err = ApiError.fromWire({
      'code': 'ws/demo_room/not_implemented',
      'message': 'Room subscribe not implemented',
    });
    expect(err.code, isA<ModuleApiErrorCode>());
    expect(err.rawCode, 'ws/demo_room/not_implemented');
  });

  test('actionFor token_expired refresh on HTTP', () {
    expect(
      actionFor(CoreApiErrorCode.tokenExpired, isWebSocket: false),
      ErrorAction.refreshAndRetry,
    );
  });

  test('actionFor token_expired reconnect on WS', () {
    expect(
      actionFor(CoreApiErrorCode.tokenExpired, isWebSocket: true),
      ErrorAction.reconnectWs,
    );
  });

  test('actionFor rate_limited showMessage', () {
    expect(
      actionFor(CoreApiErrorCode.rateLimited, isWebSocket: false),
      ErrorAction.showMessage,
    );
  });

  test('ApiError parses rate_limited', () {
    final err = ApiError.fromWire({
      'code': 'rate_limited',
      'message': 'Too many requests',
    });
    expect(err.code, CoreApiErrorCode.rateLimited);
  });
}
