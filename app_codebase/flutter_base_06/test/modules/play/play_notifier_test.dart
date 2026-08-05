import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/play/play_models.dart';
import 'package:arcori/modules/play/play_notifier.dart';

void main() {
  group('MatchFlowNotifier', () {
    test('startPlay enters selectingType; cancel returns idle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchFlowProvider.notifier);

      notifier.startPlay();
      expect(
        container.read(matchFlowProvider).phase,
        MatchFlowPhase.selectingType,
      );

      notifier.cancelSelection();
      expect(container.read(matchFlowProvider).isIdle, isTrue);
      expect(container.read(matchFlowProvider).selectedType, isNull);
    });

    test('selectType runs stub pipeline and returns to idle', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchFlowProvider.notifier);

      notifier.startPlay();
      await notifier.selectType(MatchType.practice);

      final state = container.read(matchFlowProvider);
      expect(state.isIdle, isTrue);
      expect(state.selectedType, isNull);
    });

    test('startPlay is ignored while pipeline is not idle', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchFlowProvider.notifier);

      notifier.startPlay();
      notifier.startPlay();
      expect(
        container.read(matchFlowProvider).phase,
        MatchFlowPhase.selectingType,
      );
    });
  });
}
