/// Core (framework-owned) error codes — modules must not register these.
library;

import 'error_spec.dart';

const unauthorized = ErrorSpec(
  'unauthorized',
  'Bearer token required',
  401,
  fatalWs: true,
);
const tokenExpired = ErrorSpec(
  'token_expired',
  'Access token expired',
  401,
  fatalWs: true,
);
const invalidToken = ErrorSpec(
  'invalid_token',
  'Invalid access token',
  401,
  fatalWs: true,
);
const forbidden = ErrorSpec('forbidden', 'Forbidden', 403, fatalWs: true);
const notFound = ErrorSpec('not_found', 'Not found', 404);
const invalidJson = ErrorSpec('invalid_json', 'Message must be valid JSON', 400);
const invalidMessage = ErrorSpec('invalid_message', 'Invalid message', 400);
const notImplemented = ErrorSpec('not_implemented', 'Not implemented', 501);
const rateLimited = ErrorSpec('rate_limited', 'Too many requests', 429);
const internalError = ErrorSpec('internal_error', 'Internal server error', 500);

const coreErrorSpecs = <ErrorSpec>[
  unauthorized,
  tokenExpired,
  invalidToken,
  forbidden,
  notFound,
  invalidJson,
  invalidMessage,
  notImplemented,
  rateLimited,
  internalError,
];

final coreCodes = {for (final spec in coreErrorSpecs) spec.code};
