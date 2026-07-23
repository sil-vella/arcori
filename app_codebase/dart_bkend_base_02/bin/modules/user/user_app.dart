import 'package:shelf/shelf.dart';

import '../../core/auth/auth_request.dart';
import '../../core/http/contracts/http_response_contract.dart';
import '../../core/http/contracts/register_route_contract.dart';

void registerUserRoutes(
  ApplicationRouteSink routes,
  HttpResponseContract res,
) {
  routes.publicGet(
    '/',
    (Request request) async => res.jsonOk({'message': 'dart_bkend_base_02'}),
  );
  routes.publicGet(
    '/health',
    (Request request) async => res.jsonOk({'status': 'up'}),
  );
  routes.authuserGet(
    '/user/profile',
    (Request request) async => res.jsonOk({
      'module': 'user',
      'profile': 'example',
      'user_id': authUserIdFrom(request),
    }),
  );
}
