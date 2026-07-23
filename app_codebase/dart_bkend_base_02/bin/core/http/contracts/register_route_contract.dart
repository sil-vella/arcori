/// Let feature modules attach HTTP handlers without knowing how the global route table works.
///
/// The live implementation is [applicationRoutes] in `service/routes.dart`. During startup,
/// [registerApplicationRoutes] calls into each feature, which registers GET/POST/PUT/DELETE
/// handlers here. The HTTP layer adds the right prefix and guards where needed.
///
/// Pair with `http_response_contract.dart` when a module needs to format JSON replies (import that
/// file where appropriate).
library;

import 'package:shelf/shelf.dart';

/// Register one handler per HTTP verb and path pattern.
///
/// **Public** methods: [path] is the full URL path from the site root.
///
/// **Authuser** methods: [path] is only the part after `/authuser`. The framework adds
/// `/authuser` and runs the Bearer token check before your handler.
///
/// **Service** methods: same idea for `/service` and the service-key check.
///
/// Do not put `/authuser` or `/service` inside [path] for those groups—use something like
/// `/user/profile`, not `/authuser/user/profile`.
abstract interface class ApplicationRouteSink {
  void publicGet(String path, Handler handler);
  void publicPost(String path, Handler handler);
  void publicPut(String path, Handler handler);
  void publicDelete(String path, Handler handler);

  void authuserGet(String path, Handler handler);
  void authuserPost(String path, Handler handler);
  void authuserPut(String path, Handler handler);
  void authuserDelete(String path, Handler handler);

  void serviceGet(String path, Handler handler);
  void servicePost(String path, Handler handler);
  void servicePut(String path, Handler handler);
  void serviceDelete(String path, Handler handler);
}
