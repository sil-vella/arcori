import 'package:shelf/shelf.dart';

import '../../core/http/contracts/http_response_contract.dart';
import '../../core/http/contracts/register_route_contract.dart';

void registerServiceRoutes(
  ApplicationRouteSink routes,
  HttpResponseContract res,
) {
  routes.serviceGet(
    '/health',
    (Request request) async =>
        res.jsonOk({'module': 'service', 'status': 'up'}),
  );
}
