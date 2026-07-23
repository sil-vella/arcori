/// Parsed API error from `{ok: false, error: {code, message}}`.
library;

sealed class ApiErrorCode {
  const ApiErrorCode(this.raw);

  final String raw;

  bool get isCore => this is CoreApiErrorCode;
  bool get isModule => this is ModuleApiErrorCode;

  factory ApiErrorCode.parse(String raw) {
    return CoreApiErrorCode.tryParse(raw) ?? ModuleApiErrorCode(raw);
  }
}

class CoreApiErrorCode extends ApiErrorCode {
  const CoreApiErrorCode._(super.raw);

  static const unauthorized = CoreApiErrorCode._('unauthorized');
  static const tokenExpired = CoreApiErrorCode._('token_expired');
  static const invalidToken = CoreApiErrorCode._('invalid_token');
  static const forbidden = CoreApiErrorCode._('forbidden');
  static const notFound = CoreApiErrorCode._('not_found');
  static const invalidJson = CoreApiErrorCode._('invalid_json');
  static const invalidMessage = CoreApiErrorCode._('invalid_message');
  static const notImplemented = CoreApiErrorCode._('not_implemented');
  static const rateLimited = CoreApiErrorCode._('rate_limited');
  static const internalError = CoreApiErrorCode._('internal_error');

  static const _known = {
    'unauthorized': unauthorized,
    'token_expired': tokenExpired,
    'invalid_token': invalidToken,
    'forbidden': forbidden,
    'not_found': notFound,
    'invalid_json': invalidJson,
    'invalid_message': invalidMessage,
    'not_implemented': notImplemented,
    'rate_limited': rateLimited,
    'internal_error': internalError,
  };

  static CoreApiErrorCode? tryParse(String raw) => _known[raw];
}

class ModuleApiErrorCode extends ApiErrorCode {
  const ModuleApiErrorCode(super.raw);
}

class ApiError implements Exception {
  ApiError({
    required this.code,
    required this.message,
    required this.rawCode,
  });

  final ApiErrorCode code;
  final String message;
  final String rawCode;

  factory ApiError.fromWire(Map<String, dynamic> error) {
    final rawCode = error['code']?.toString() ?? 'internal_error';
    final message = error['message']?.toString() ?? 'Error';
    return ApiError(
      code: ApiErrorCode.parse(rawCode),
      message: message,
      rawCode: rawCode,
    );
  }

  factory ApiError.fromEnvelope(Map<String, dynamic> envelope) {
    final err = envelope['error'];
    if (err is Map<String, dynamic>) {
      return ApiError.fromWire(err);
    }
    if (err is Map) {
      return ApiError.fromWire(Map<String, dynamic>.from(err));
    }
    return ApiError(
      code: CoreApiErrorCode.internalError,
      message: 'Unknown error',
      rawCode: 'internal_error',
    );
  }

  @override
  String toString() => 'ApiError($rawCode): $message';
}
