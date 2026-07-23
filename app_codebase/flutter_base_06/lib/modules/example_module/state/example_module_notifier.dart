import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'example_module_replay.dart';
import 'example_module_state.dart';

class ExampleModuleNotifier extends Notifier<ExampleModuleState> {
  @override
  ExampleModuleState build() {
    ref.listen<ExampleModulePending?>(exampleModuleReplayProvider, (_, next) {
      if (next != null) {
        applyWsPatch(next.connectionId, next.data);
        Future.microtask(ref.read(exampleModuleReplayProvider.notifier).take);
      }
    });

    final pending = ref.read(exampleModuleReplayProvider);
    if (pending != null) {
      Future.microtask(ref.read(exampleModuleReplayProvider.notifier).take);
      return _stateFromPatch(const ExampleModuleState(), pending.data);
    }
    return const ExampleModuleState();
  }

  void bumpLocal() {
    state = state.copyWith(
      revision: state.revision + 1,
      message: 'local bump',
      lastEvent: 'local',
    );
  }

  void applyWsPatch(String connectionId, Map<String, dynamic> data) {
    state = _stateFromPatch(state, data).copyWith(
      lastEvent: '$connectionId: ${data['channel'] ?? 'example/state'}',
    );
  }

  ExampleModuleState _stateFromPatch(
    ExampleModuleState current,
    Map<String, dynamic> data,
  ) {
    final payload = data['payload'];
    final map = payload is Map
        ? Map<String, dynamic>.from(payload)
        : Map<String, dynamic>.from(data);
    return current.copyWith(
      revision: map['revision'] is int ? map['revision'] as int : current.revision,
      message: map['message']?.toString() ?? current.message,
    );
  }
}

final exampleModuleProvider =
    NotifierProvider<ExampleModuleNotifier, ExampleModuleState>(
  ExampleModuleNotifier.new,
);
