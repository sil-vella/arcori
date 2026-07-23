/// Immutable example_module snapshot — tier 3 domain (template demo).
class ExampleModuleState {
  const ExampleModuleState({
    this.revision = 0,
    this.message = 'idle',
    this.lastEvent,
  });

  final int revision;
  final String message;
  final String? lastEvent;

  ExampleModuleState copyWith({
    int? revision,
    String? message,
    String? lastEvent,
  }) {
    return ExampleModuleState(
      revision: revision ?? this.revision,
      message: message ?? this.message,
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}
