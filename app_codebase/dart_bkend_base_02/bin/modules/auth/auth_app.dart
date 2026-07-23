import 'package:shelf/shelf.dart';

import '../../core/http/contracts/http_response_contract.dart';
import '../../core/http/contracts/register_route_contract.dart';
import 'auth_service.dart';

void registerAuthRoutes(
  ApplicationRouteSink routes,
  HttpResponseContract res,
) {
  routes.publicPost(
    '/public/auth/dev-login',
    (Request request) async => _handleDevLogin(request, res),
  );
  routes.publicPost(
    '/public/auth/refresh',
    (Request request) async => _handleRefresh(request, res),
  );
  routes.servicePost(
    '/auth/validate',
    (Request request) async => _handleValidate(request, res),
  );
}

Future<Response> _handleDevLogin(
  Request request,
  HttpResponseContract res,
) async {
  final body = await readJsonBody(request);
  final payload = devLogin(body['user_id']?.toString() ?? '');
  if (payload == null) {
    return res.jsonError(
      code: 'forbidden',
      message: 'Dev login is not available',
      status: 403,
    );
  }
  return res.jsonOk(payload);
}

Future<Response> _handleRefresh(
  Request request,
  HttpResponseContract res,
) async {
  final body = await readJsonBody(request);
  final payload = refreshAccessToken(body['refresh_token']?.toString() ?? '');
  if (payload == null) {
    return res.jsonError(
      code: 'invalid_token',
      message: 'Invalid or expired refresh token',
      status: 401,
    );
  }
  return res.jsonOk(payload);
}

Future<Response> _handleValidate(
  Request request,
  HttpResponseContract res,
) async {
  final body = await readJsonBody(request);
  final payload = validateAccessToken(body['access_token']?.toString() ?? '');
  if (payload == null) {
    return res.jsonError(
      code: 'invalid_token',
      message: 'Invalid or expired access token',
      status: 401,
    );
  }
  return res.jsonOk(payload);
}
