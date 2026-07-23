import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/state/app_state_registry.dart';
import 'package:arcori/modules/example_module/register_example_module_state.dart';
import 'package:arcori/modules/example_module/state/example_module_notifier.dart';

void main() {
  group('ExampleModuleNotifier', () {
    test('bumpLocal increments revision', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(exampleModuleProvider.notifier).bumpLocal();

      expect(container.read(exampleModuleProvider).revision, 1);
      expect(container.read(exampleModuleProvider).message, 'local bump');
    });

    test('registered handler updates state via replay listener', () {
      resetAppStateRegistry();
      registerExampleModuleState(appStateSink);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      late Ref ref;
      container.read(Provider((r) {
        ref = r;
        return 0;
      }));

      container.read(exampleModuleProvider);

      final router = buildWsChannelRouter(ref);
      router.dispatch('dart', {
        'channel': 'example/state',
        'payload': {'revision': 2, 'message': 'from-ws'},
      });

      expect(container.read(exampleModuleProvider).message, 'from-ws');
    });
  });
}
