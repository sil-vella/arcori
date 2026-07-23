/// Shared service key verification for HTTP guards and WS auth handshake.
library;

import '../errors/app_error.dart';
import '../errors/error_codes.dart';
import 'auth_config.dart';
import 'secret_compare.dart';

void verifyServiceKeyOrThrow(String? provided) {
  final expected = serviceKey();
  final value = (provided ?? '').trim();
  if (value.isEmpty || expected.isEmpty || !secretsEqual(value, expected)) {
    throw AppError(forbidden, message: 'Invalid service key');
  }
}
