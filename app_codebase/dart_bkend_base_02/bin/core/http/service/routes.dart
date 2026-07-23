/// Store handlers keyed by HTTP method plus path, and send each request to the right one.
///
/// Registration goes through [applicationRoutes], which implements [ApplicationRouteSink]. There
/// are three groups: **public** routes use the URL path you pass as-is; **authuser** routes are
/// served under `/authuser/...` and wrap the handler so a Bearer token must be present first;
/// **service** routes are under `/service/...` and require a service key header first. Paths are
/// normalized (for example trailing slashes) so lookups stay consistent.
///
/// If nothing matches, the dispatcher returns JSON with HTTP 404. [resetRouteRegistry] and
/// [buildApplicationHandler] are used from [createHttpHandler] in `http_app.dart` when the app
/// starts.
library;

import 'package:shelf/shelf.dart';

import '../contracts/register_route_contract.dart';
import '../middleware/authuser_guard.dart';
import '../middleware/service_guard.dart';
import '../response/response.dart';

const String _prefixAuthuser = '/authuser';
const String _prefixService = '/service';

final ApplicationRouteSink applicationRoutes = _RouteRegistry._instance;

void resetRouteRegistry() => _RouteRegistry._instance.clear();

Handler buildApplicationHandler() {
  return _RouteRegistry._instance._dispatch;
}

String _normalizePath(String path) {
  if (path.isEmpty) return '/';
  var normalized = path.startsWith('/') ? path : '/$path';
  if (normalized != '/' && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

/// Joins a tier prefix with a tier-relative path from module registration.
String _joinTierPath(String tierPrefix, String path) {
  final p = _normalizePath(path);
  if (tierPrefix.isEmpty) return p;
  if (p == '/') return tierPrefix;
  return '$tierPrefix$p';
}

class _RouteRegistry implements ApplicationRouteSink {
  _RouteRegistry._();

  static final _RouteRegistry _instance = _RouteRegistry._();

  final Map<String, Handler> _routes = {};

  void clear() => _routes.clear();

  void _add(String method, String path, Handler handler) {
    final key = '${method.toUpperCase()} ${_normalizePath(path)}';
    _routes[key] = handler;
  }

  Handler _wrapAuthuser(Handler inner) =>
      Pipeline().addMiddleware(authuserGuard()).addHandler(inner);

  Handler _wrapService(Handler inner) =>
      Pipeline().addMiddleware(serviceGuard()).addHandler(inner);

  @override
  void publicGet(String path, Handler handler) => _add('GET', path, handler);

  @override
  void publicPost(String path, Handler handler) => _add('POST', path, handler);

  @override
  void publicPut(String path, Handler handler) => _add('PUT', path, handler);

  @override
  void publicDelete(String path, Handler handler) =>
      _add('DELETE', path, handler);

  @override
  void authuserGet(String path, Handler handler) => _add(
        'GET',
        _joinTierPath(_prefixAuthuser, path),
        _wrapAuthuser(handler),
      );

  @override
  void authuserPost(String path, Handler handler) => _add(
        'POST',
        _joinTierPath(_prefixAuthuser, path),
        _wrapAuthuser(handler),
      );

  @override
  void authuserPut(String path, Handler handler) => _add(
        'PUT',
        _joinTierPath(_prefixAuthuser, path),
        _wrapAuthuser(handler),
      );

  @override
  void authuserDelete(String path, Handler handler) => _add(
        'DELETE',
        _joinTierPath(_prefixAuthuser, path),
        _wrapAuthuser(handler),
      );

  @override
  void serviceGet(String path, Handler handler) => _add(
        'GET',
        _joinTierPath(_prefixService, path),
        _wrapService(handler),
      );

  @override
  void servicePost(String path, Handler handler) => _add(
        'POST',
        _joinTierPath(_prefixService, path),
        _wrapService(handler),
      );

  @override
  void servicePut(String path, Handler handler) => _add(
        'PUT',
        _joinTierPath(_prefixService, path),
        _wrapService(handler),
      );

  @override
  void serviceDelete(String path, Handler handler) => _add(
        'DELETE',
        _joinTierPath(_prefixService, path),
        _wrapService(handler),
      );

  Future<Response> _dispatch(Request request) async {
    final method = request.method.toUpperCase();
    final path = _normalizePath(request.requestedUri.path);
    final key = '$method $path';
    final handler = _routes[key];
    if (handler == null) {
      return jsonError(
        code: 'not_found',
        message: 'No route for $method $path',
        status: 404,
      );
    }
    return await handler(request);
  }
}
