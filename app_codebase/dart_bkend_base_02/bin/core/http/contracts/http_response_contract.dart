/// Define what “sending JSON back” looks like to feature code.
///
/// Handlers often receive an object that implements this interface so they can return success
/// payloads or structured errors without building [Response] objects manually. That keeps tests
/// simpler and imports smaller.
///
/// The running app usually passes [httpResponses] from `response/response.dart`, which implements
/// this interface.
library;

import 'package:shelf/shelf.dart';

abstract interface class HttpResponseContract {
  Response jsonOk(Object? data, {int status});

  Response jsonError({
    required String code,
    required String message,
    int status,
  });
}
