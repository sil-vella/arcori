import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

import 'core/ws/ws_app.dart';
import 'utils/dev_logger.dart';

const bool LOGGING_SWITCH = false; // ignore: constant_identifier_names

/// Builds the HTTP + WebSocket stack and starts the Shelf server.
Future<void> startApp() async {
  await _startShelfServer(createCombinedHandler());
}

/// Wraps [innerHandler] with request logging, binds to all interfaces, reads [PORT].
Future<void> _startShelfServer(Handler innerHandler) async {
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(innerHandler);

  final ip = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  if (LOGGING_SWITCH) {
    customlog('Server listening on port ${server.port}');
  }
  print('Server listening on port ${server.port}');
}
