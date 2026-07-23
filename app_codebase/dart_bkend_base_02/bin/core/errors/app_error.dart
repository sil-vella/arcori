/// Raise in handlers; convert to HTTP or WS envelope.
library;

import 'package:shelf/shelf.dart';

import '../http/response/response.dart';
import '../ws/response/ws_response.dart';
import 'error_spec.dart';

class AppError implements Exception {
  AppError(this.spec, {String? message}) : message = message ?? spec.message;

  final ErrorSpec spec;
  final String message;

  String get code => spec.code;

  Response toShelfResponse() => jsonError(
        code: code,
        message: message,
        status: spec.httpStatus,
      );

  String toWsFrame() => encodeWsError(code: code, message: message);
}
