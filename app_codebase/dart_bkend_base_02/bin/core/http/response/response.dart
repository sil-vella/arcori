/// Shared JSON format for every API response: either `ok` plus `data`, or `ok` false plus an
/// `error` object with `code` and `message`.
///
/// The functions [jsonOk] and [jsonError] build full Shelf [Response] values with the right
/// content type. Route handlers use them directly or through [ShelfJsonHttpResponses]; middleware
/// and the “no such route” path use them too so clients always see the same structure.
///
/// [httpResponses] is a single object you can pass anywhere an [HttpResponseContract] is
/// expected.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../contracts/http_response_contract.dart';

Map<String, Object?> jsonSuccessBody(Object? data) => {
      'ok': true,
      'data': data,
    };

Map<String, Object?> jsonErrorBody({
  required String code,
  required String message,
}) =>
    {
      'ok': false,
      'error': {
        'code': code,
        'message': message,
      },
    };

Response _shelfJsonOk(Object? data, {int status = 200}) => Response(
      status,
      body: jsonEncode(jsonSuccessBody(data)),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Response _shelfJsonError({
  required String code,
  required String message,
  int status = 400,
}) =>
    Response(
      status,
      body: jsonEncode(jsonErrorBody(code: code, message: message)),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// JSON success reply with optional HTTP status. Core code and guards call this; feature modules
/// usually go through [HttpResponseContract] instead.
Response jsonOk(Object? data, {int status = 200}) =>
    _shelfJsonOk(data, status: status);

/// JSON error reply: you choose the HTTP status; the body uses the same overall JSON shape as
/// success, with `ok: false` and an `error` block.
Response jsonError({
  required String code,
  required String message,
  int status = 400,
}) =>
    _shelfJsonError(code: code, message: message, status: status);

/// Delegates to [jsonOk] / [jsonError] so [HttpResponseContract] can be satisfied without extra
/// duplication.
final class ShelfJsonHttpResponses implements HttpResponseContract {
  const ShelfJsonHttpResponses();

  @override
  Response jsonOk(Object? data, {int status = 200}) =>
      _shelfJsonOk(data, status: status);

  @override
  Response jsonError({
    required String code,
    required String message,
    int status = 400,
  }) =>
      _shelfJsonError(code: code, message: message, status: status);
}

/// Default [HttpResponseContract] instance for passing into feature registration functions.
const HttpResponseContract httpResponses = ShelfJsonHttpResponses();
