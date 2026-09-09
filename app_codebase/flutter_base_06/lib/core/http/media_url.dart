/// Resolve relative media paths against the API REST base URL.
library;

import '../ws/ws_config.dart';

/// Shared Arcori disc back (practice + multi). Bundle asset under Flutter.
const String kArcoriBackAssetPath = 'assets/images/arcori/back-side.webp';

/// True when [path] is a Flutter bundle asset (`assets/...` or `asset:...`).
bool isBundleAssetMedia(String? path) {
  if (path == null || path.isEmpty) return false;
  return path.startsWith('assets/') || path.startsWith('asset:');
}

/// Strip optional `asset:` prefix for [Image.asset] / [AssetImage].
String bundleAssetPath(String path) {
  if (path.startsWith('asset:')) return path.substring('asset:'.length);
  return path;
}

String resolveMediaUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (isBundleAssetMedia(path)) return bundleAssetPath(path);
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  final base = WsConfig.apiRestBase.replaceAll(RegExp(r'/+$'), '');
  if (path.startsWith('/')) {
    return '$base$path';
  }
  return '$base/$path';
}
