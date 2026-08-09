import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/match/state/match_notifier.dart';
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

    test('practice auto stub loop returns to idle without manual End',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final flow = container.read(matchFlowProvider.notifier);
      flow.practiceStubStepDelay = Duration.zero;

      flow.startPlay();
      await flow.selectType(
        MatchType.practice,
        practiceLoadout: const PracticeLoadout(
          arcoriId: 'ANM-TIG-GEN001-0001',
          slammerId: stubSlammerId,
        ),
      );

      expect(container.read(matchFlowProvider).isIdle, isTrue);
      expect(container.read(matchSnapshotProvider).matchId, isNull);
    });

    test('non-practice room stub returns to idle without match snapshot',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchFlowProvider.notifier);

      notifier.startPlay();
      await notifier.selectType(MatchType.quickStart);

      expect(container.read(matchFlowProvider).isIdle, isTrue);
      expect(container.read(matchSnapshotProvider).matchId, isNull);
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
