import 'package:flutter_riverpod/flutter_riverpod.dart';

class MatchPending {
  const MatchPending({required this.connectionId, required this.data});

  final String connectionId;
  final Map<String, dynamic> data;
}

class MatchReplay extends Notifier<MatchPending?> {
  @override
  MatchPending? build() => null;

  void store(String connectionId, Map<String, dynamic> data) {
    state = MatchPending(connectionId: connectionId, data: data);
  }

  MatchPending? take() {
    final pending = state;
    state = null;
    return pending;
  }
}

final matchReplayProvider =
    NotifierProvider<MatchReplay, MatchPending?>(MatchReplay.new);
