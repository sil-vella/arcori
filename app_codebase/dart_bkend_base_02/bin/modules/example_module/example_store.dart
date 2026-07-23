/// Minimal tier-3 snapshot for the cross-stack example module.
library;

class ExampleSnapshot {
  const ExampleSnapshot({
    required this.revision,
    required this.message,
  });

  final int revision;
  final String message;

  ExampleSnapshot copyWith({int? revision, String? message}) {
    return ExampleSnapshot(
      revision: revision ?? this.revision,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'revision': revision,
      'message': message,
    };
  }

  static ExampleSnapshot fromPayload(Map<String, dynamic> payload) {
    return ExampleSnapshot(
      revision: payload['revision'] is int ? payload['revision'] as int : 0,
      message: payload['message']?.toString() ?? '',
    );
  }
}

/// In-memory store — module-owned, not core gameplay infrastructure.
class ExampleModuleStore {
  ExampleSnapshot _snapshot = const ExampleSnapshot(revision: 0, message: 'idle');

  void reset() {
    _snapshot = const ExampleSnapshot(revision: 0, message: 'idle');
  }

  ExampleSnapshot get snapshot => _snapshot;

  ExampleSnapshot applyPatch(Map<String, dynamic> patch) {
    _snapshot = _snapshot.copyWith(
      revision: _snapshot.revision + 1,
      message: patch['message']?.toString() ?? _snapshot.message,
    );
    return _snapshot;
  }
}

final exampleModuleStore = ExampleModuleStore();

void resetExampleModuleState() {
  exampleModuleStore.reset();
}
