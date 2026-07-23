/// Wrap handlers registered through the service methods on [ApplicationRouteSink].
///
/// Before the inner handler runs, we require `X-Service-Key` to match `SERVICE_KEY` from the
/// environment. On failure we return JSON 403.
library;

import 'package:shelf/shelf.dart';

import '../../auth/auth_config.dart';
import '../../auth/verify_service_key.dart';
import '../../errors/app_error.dart';
import '../../errors/error_codes.dart';
import '../response/response.dart';

Middleware serviceGuard() {
  return (Handler inner) {
    return (Request request) async {
      if (isProduction() && serviceKey().isEmpty) {
        return jsonError(
          code: forbidden.code,
          message: 'Service authentication unavailable',
          status: forbidden.httpStatus,
        );
      }
      try {
        verifyServiceKeyOrThrow(request.headers['X-Service-Key']);
        return inner(request);
      } on AppError catch (err) {
        return err.toShelfResponse();
      }
    };
  };
}
