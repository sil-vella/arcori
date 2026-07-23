/// WebSocket / REST base URLs — set via dart-define from .env.dart.defines.* (wfrun → launch scripts).
class WsConfig {
  const WsConfig._();

  static const apiAuthuserUrl = String.fromEnvironment('ARCORI_API_WS_URL');

  static const dartAuthuserUrl = String.fromEnvironment('ARCORI_DART_WS_URL');

  static const apiRestBase = String.fromEnvironment('ARCORI_API_REST_URL');
}
