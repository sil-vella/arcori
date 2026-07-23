/// Wrap handlers registered through the authuser methods on [ApplicationRouteSink].
///
/// Before the inner handler runs, we require a valid Bearer access JWT. On success we attach
/// user context to [Request.context]. On failure we return JSON 401.
library;

import 'package:shelf/shelf.dart';

import '../../auth/auth_context.dart';
import '../../auth/verify_access.dart';
import '../../errors/app_error.dart';

String? _extractBearerToken(Request request) {
  final auth = request.headers['Authorization'];
  if (auth == null || !auth.toLowerCase().startsWith('bearer ')) {
    return null;
  }
  final token = auth.substring(7).trim();
  return token.isEmpty ? null : token;
}

Middleware authuserGuard() {
  return (Handler inner) {
    return (Request request) async {
      try {
        final ctx = verifyBearerOrThrow(_extractBearerToken(request));
        final updated = request.change(
          context: {
            ...request.context,
            authUserIdContextKey: ctx.userId,
            authClaimsContextKey: ctx.claims,
          },
        );
        return inner(updated);
      } on AppError catch (err) {
        return err.toShelfResponse();
      }
    };
  };
}
