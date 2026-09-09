import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/match/state/match_notifier.dart';
import 'package:arcori/modules/play/play_models.dart';
import 'package:arcori/modules/play/play_notifier.dart';

Future<void> _waitUntil(
  bool Function() pred, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (pred()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('waitUntil timed out');
}

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

    test('practice holds ended snapshot until Done', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final flow = container.read(matchFlowProvider.notifier);
      flow.practiceFastStub = true;

      flow.startPlay();
      final pipeline = flow.selectType(
        MatchType.practice,
        practiceLoadout: const PracticeLoadout(
          arcoriId: 'ANM-TIG-GEN001-0001',
          slammerId: stubSlammerId,
        ),
      );

      await _waitUntil(
        () =>
            container.read(matchFlowProvider).phase == MatchFlowPhase.postMatch,
      );
      expect(container.read(matchSnapshotProvider).isEnded, isTrue);
      expect(container.read(matchSnapshotProvider).matchId, isNotNull);

      // Practice has no other humans — Rematch stays disabled.
      expect(flow.rematchAvailable(), isFalse);
      expect(
        flow.rematchDisabledReason(),
        contains('Practice'),
      );

      flow.completePostMatchDone();
      await pipeline;

      expect(container.read(matchFlowProvider).isIdle, isTrue);
      expect(container.read(matchSnapshotProvider).matchId, isNull);
    });

    test('invite without auth aborts idle with errorMessage', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchFlowProvider.notifier);

      notifier.startPlay();
      await notifier.selectType(MatchType.invite);

      expect(container.read(matchFlowProvider).isIdle, isTrue);
      expect(container.read(matchFlowProvider).errorMessage, isNotNull);
      expect(container.read(matchFlowProvider).errorMessage, contains('Sign in'));
      expect(container.read(matchSnapshotProvider).matchId, isNull);
    });

    test('quickStart without auth aborts idle with errorMessage', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchFlowProvider.notifier);

      notifier.startPlay();
      await notifier.selectType(MatchType.quickStart);

      final flow = container.read(matchFlowProvider);
      expect(flow.isIdle, isTrue);
      expect(flow.errorMessage, isNotNull);
      expect(flow.errorMessage, contains('Sign in'));

      notifier.clearError();
      expect(container.read(matchFlowProvider).errorMessage, isNull);
    });

    test('startPlay is ignored while pipeline is not idle', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchFlowProvider.notifier);

      notifier.startPlay();
      expect(
        container.read(matchFlowProvider).phase,
        MatchFlowPhase.selectingType,
      );
      notifier.startPlay();
      expect(
        container.read(matchFlowProvider).phase,
        MatchFlowPhase.selectingType,
      );
    });
  });
}
