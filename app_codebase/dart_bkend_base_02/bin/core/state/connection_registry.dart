/// Tier 2 — registered WS connections for outbound broadcast.
library;

typedef ConnectionSend = void Function(String frame);

class ConnectionRegistry {
  final Map<String, ConnectionSend> _senders = {};

  void clear() => _senders.clear();

  void register(String connectionId, ConnectionSend send) {
    _senders[connectionId] = send;
  }

  void unregister(String connectionId) {
    _senders.remove(connectionId);
  }

  bool contains(String connectionId) => _senders.containsKey(connectionId);

  int get connectionCount => _senders.length;

  void send(String connectionId, String frame) {
    _senders[connectionId]?.call(frame);
  }
}
