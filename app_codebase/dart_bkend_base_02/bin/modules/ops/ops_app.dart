/// Ops HTTP routes — drain-mode and drain-status (service tier).
library;

import 'package:shelf/shelf.dart';

import '../../core/http/contracts/http_response_contract.dart';
import '../../core/http/contracts/register_route_contract.dart';
import '../auth/auth_service.dart';
import 'ops_service.dart';

void registerOpsRoutes(
  ApplicationRouteSink routes,
  HttpResponseContract res,
) {
  routes.servicePost(
    '/ops/drain-mode',
    (Request request) async => _handleDrainMode(request, res),
  );
  routes.serviceGet(
    '/ops/drain-status',
    (Request request) async => _handleDrainStatus(res),
  );
}

Future<Response> _handleDrainMode(
  Request request,
  HttpResponseContract res,
) async {
  final body = await readJsonBody(request);
  final enabled = body['enabled'] == true;
  setDrainMode(enabled);
  return res.jsonOk({
    'drain_mode': enabled,
  });
}

Future<Response> _handleDrainStatus(HttpResponseContract res) async {
  return res.jsonOk(drainStatus());
}
