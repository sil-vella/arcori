/// Build the Shelf [Handler] the process will serve.
///
/// Order matters: we clear any previous route list so tests and restarts do not accumulate
/// duplicate routes; then [registerApplicationRoutes] (from `module_registry.dart`) runs so each
/// feature registers endpoints on [applicationRoutes]; finally we return the handler from
/// [buildApplicationHandler] that looks up URLs in that list. The server entrypoint should call
/// [createHttpHandler] to obtain this handler.
library;

import 'package:shelf/shelf.dart';

import '../../modules/module_registry.dart';
import '../errors/module_error_registry.dart';
import 'middleware/error_middleware.dart';
import 'service/routes.dart';

Handler createHttpHandler() {
  resetModuleErrorRegistry();
  registerApplicationErrors();
  resetRouteRegistry();
  registerApplicationRoutes();
  return Pipeline()
      .addMiddleware(errorMiddleware())
      .addHandler(buildApplicationHandler());
}
