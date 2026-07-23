import 'dart:convert';

import 'package:test/test.dart';

import '../bin/core/auth/verify_access.dart';
import '../bin/core/errors/app_error.dart';
import '../bin/core/errors/error_codes.dart';
import '../bin/core/errors/error_spec.dart';
import '../bin/core/errors/module_error_registry.dart';
import '../bin/modules/ws/demo_errors.dart';

void main() {
  test('AppError HTTP and WS envelope match catalog', () async {
    final err = AppError(tokenExpired);
    final response = err.toShelfResponse();
    expect(response.statusCode, 401);
    final body = jsonDecode(await response.readAsString());
    expect(body, {
      'ok': false,
      'error': {'code': 'token_expired', 'message': 'Access token expired'},
    });

    final frame = jsonDecode(err.toWsFrame());
    expect(frame, body);
  });

  test('verifyBearerOrThrow missing token', () {
    expect(
      () => verifyBearerOrThrow(null),
      throwsA(isA<AppError>().having((e) => e.code, 'code', 'unauthorized')),
    );
  });

  test('module error registration', () {
    resetModuleErrorRegistry();
    registerDemoErrors(moduleErrorRegistrar);
    final err = AppError(demoRoomNotImplemented);
    expect(err.code, 'ws/demo_room/not_implemented');
    expect(coreCodes.contains(err.code), isFalse);
  });

  test('module registrar rejects core collision', () {
    final reg = ModuleErrorRegistry();
    expect(
      () => reg.registerModule('ws', [
        const ErrorSpec('unauthorized', 'nope', 401),
      ]),
      throwsArgumentError,
    );
  });
}
