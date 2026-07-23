/// Mount WebSocket tier endpoints and combine with HTTP handler.
library;

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/auth_config.dart';
import '../errors/module_error_registry.dart';
import '../http/middleware/error_middleware.dart';
import '../http/service/routes.dart';
import '../../modules/module_registry.dart';
import 'service/channel_registry.dart';
import 'ws_dispatcher.dart';

Handler createCombinedHandler() {
  requireSecretsForProduction();
  resetModuleErrorRegistry();
  registerApplicationErrors();
  resetRouteRegistry();
  registerApplicationRoutes();
  registerApplicationState();
  resetChannelRegistry();
  registerApplicationWsChannels();

  final httpHandler = Pipeline()
      .addMiddleware(errorMiddleware())
      .addHandler(buildApplicationHandler());
  final wsHandler = _buildWsHandler();

  return (Request request) async {
    final path = request.requestedUri.path;
    if (path.startsWith('/ws/')) {
      return wsHandler(request);
    }
    return httpHandler(request);
  };
}

Handler _buildWsHandler() {
  Handler mount(String tier) {
    return webSocketHandler((WebSocketChannel channel, _) {
      runWsConnection(channel, tier: tier);
    });
  }

  final public = mount('public');
  final authuser = mount('authuser');
  final service = mount('service');

  return (Request request) async {
    final path = request.requestedUri.path;
    if (path == '/ws/public') return public(request);
    if (path == '/ws/authuser') return authuser(request);
    if (path == '/ws/service') return service(request);
    return Response.notFound('WebSocket endpoint not found');
  };
}
