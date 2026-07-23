import 'package:shelf/shelf.dart';

import 'auth_context.dart';

String? authUserIdFrom(Request request) {
  final value = request.context[authUserIdContextKey];
  if (value is String) return value;
  return null;
}
