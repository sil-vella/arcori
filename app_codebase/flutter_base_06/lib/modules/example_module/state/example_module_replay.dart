import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExampleModulePending {
  const ExampleModulePending({required this.connectionId, required this.data});

  final String connectionId;
  final Map<String, dynamic> data;
}

class ExampleModuleReplay extends Notifier<ExampleModulePending?> {
  @override
  ExampleModulePending? build() => null;

  void store(String connectionId, Map<String, dynamic> data) {
    state = ExampleModulePending(connectionId: connectionId, data: data);
  }

  ExampleModulePending? take() {
    final pending = state;
    state = null;
    return pending;
  }
}

final exampleModuleReplayProvider =
    NotifierProvider<ExampleModuleReplay, ExampleModulePending?>(
  ExampleModuleReplay.new,
);
