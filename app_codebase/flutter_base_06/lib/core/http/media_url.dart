/// Resolve relative media paths against the API REST base URL.
library;

import '../ws/ws_config.dart';

String resolveMediaUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  final base = WsConfig.apiRestBase.replaceAll(RegExp(r'/+$'), '');
  if (path.startsWith('/')) {
    return '$base$path';
  }
  return '$base/$path';
}
