/// Routes inbound WebSocket data frames to module-registered handlers by channel prefix.
library;

typedef WsChannelHandler = void Function(
  String connectionId,
  Map<String, dynamic> data,
);

/// Prefix registration API passed to modules during bootstrap.
class WsChannelRegistrar {
  WsChannelRegistrar(this._router);

  final WsChannelRouter _router;

  /// [prefix] matches exact channel or `prefix/...` (e.g. `demo`, `match/state`).
  void onPrefix(String prefix, WsChannelHandler handler) {
    _router.register(prefix, handler);
  }
}

class WsChannelRouter {
  final List<({String prefix, WsChannelHandler handler})> _handlers = [];

  void register(String prefix, WsChannelHandler handler) {
    _handlers.add((prefix: prefix, handler: handler));
  }

  void clear() => _handlers.clear();

  /// Dispatches [data] to handlers whose prefix matches [channel].
  void dispatch(String connectionId, Map<String, dynamic> data) {
    final channel = data['channel']?.toString() ?? '';
    if (channel.isEmpty) {
      return;
    }
    for (final entry in _handlers) {
      final prefix = entry.prefix;
      if (channel == prefix || channel.startsWith('$prefix/')) {
        entry.handler(connectionId, data);
      }
    }
  }
}
