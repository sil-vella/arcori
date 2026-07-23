/// Top-level HTTP exception boundary — map [AppError] to JSON envelope.
library;

import 'package:shelf/shelf.dart';

import '../../errors/app_error.dart';
import '../../errors/error_codes.dart';

Middleware errorMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      try {
        return await inner(request);
      } on AppError catch (err) {
        return err.toShelfResponse();
      } catch (_) {
        return AppError(internalError).toShelfResponse();
      }
    };
  };
}
