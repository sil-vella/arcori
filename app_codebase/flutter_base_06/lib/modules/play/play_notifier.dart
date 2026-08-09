import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth/auth_providers.dart';
import '../../utils/dev_logger.dart';
import '../match/state/match_notifier.dart';
import 'play_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

final matchFlowProvider =
    NotifierProvider<MatchFlowNotifier, MatchFlowState>(MatchFlowNotifier.new);

/// Owns the Play → type select → setup → match → post-match pipeline.
///
/// Practice is Flutter-only (local snapshot). Other types hit a room-create stub.
class MatchFlowNotifier extends Notifier<MatchFlowState> {
  int _runId = 0;

  @override
  MatchFlowState build() => const MatchFlowState();

  void startPlay() {
    if (!state.isIdle) return;
    _setPhase(MatchFlowPhase.selectingType);
  }

  void cancelSelection() {
    if (state.phase != MatchFlowPhase.selectingType &&
        state.phase != MatchFlowPhase.typeSetup) {
      return;
    }
    _runId++;
    state = const MatchFlowState();
    if (LOGGING_SWITCH) {
      customlog('play: cancelSelection → idle');
    }
  }

  /// [practiceLoadout] used for practice local seats; ignored for other types.
  Future<void> selectType(
    MatchType type, {
    PracticeLoadout? practiceLoadout,
  }) async {
    if (state.phase != MatchFlowPhase.selectingType) return;
    final runId = ++_runId;
    state = MatchFlowState(
      phase: MatchFlowPhase.typeSetup,
      selectedType: type,
      practiceLoadout: practiceLoadout,
    );
    if (LOGGING_SWITCH) {
      customlog('play: selectType=${type.name} → typeSetup');
    }

    await _runTypeSetup(type);
    if (!_isCurrentRun(runId, type)) return;

    if (type == MatchType.practice) {
      _setPhase(MatchFlowPhase.inMatch);
      await _runPracticeLocal(practiceLoadout);
      if (!_isCurrentRun(runId, type)) return;
    } else {
      await _runRoomCreateStub(type);
      if (!_isCurrentRun(runId, type)) return;
    }

    _setPhase(MatchFlowPhase.postMatch);
    await _runPostMatch();
    if (!_isCurrentRun(runId, type)) return;

    state = const MatchFlowState();
    if (LOGGING_SWITCH) {
      customlog('play: pipeline done → idle');
    }
  }

  bool _isCurrentRun(int runId, MatchType type) {
    return runId == _runId && state.selectedType == type;
  }

  void _setPhase(MatchFlowPhase phase) {
    state = state.copyWith(phase: phase);
    if (LOGGING_SWITCH) {
      customlog('play: phase=${phase.name}');
    }
  }

  Future<void> _runTypeSetup(MatchType type) async {
    if (LOGGING_SWITCH) {
      customlog(
        'play: typeSetup type=${type.name} '
        'loadout=${state.practiceLoadout?.arcoriId ?? '-'}',
      );
    }
  }

  /// Step delay for auto stub practice loop (tests may set [Duration.zero]).
  Duration practiceStubStepDelay = practiceStubStepDelayDefault;

  /// Flutter-only practice: local human + 2 AI. Auto stub loop then end.
  Future<void> _runPracticeLocal(PracticeLoadout? loadout) async {
    final effective = loadout ??
        const PracticeLoadout(
          arcoriId: 'ANM-TIG-GEN001-0001',
          slammerId: stubSlammerId,
        );
    final userId = ref.read(authProvider).userId?.trim();
    final humanId =
        (userId != null && userId.isNotEmpty) ? userId : 'local';

    final match = ref.read(matchSnapshotProvider.notifier);
    match.clear();
    match.startLocalPractice(humanUserId: humanId, loadout: effective);

    if (LOGGING_SWITCH) {
      customlog(
        'play: practiceLocal started human=$humanId '
        'arcori=${effective.arcoriId}',
      );
    }

    await match.runLocalPracticeStubMatch(stepDelay: practiceStubStepDelay);

    if (LOGGING_SWITCH) {
      final snap = ref.read(matchSnapshotProvider);
      customlog(
        'play: practiceLocal finished ended=${snap.isEnded} '
        'round=${snap.round}',
      );
    }
    match.clear();
  }

  /// Online room create — stub only (no Dart WS yet).
  Future<void> _runRoomCreateStub(MatchType type) async {
    if (LOGGING_SWITCH) {
      customlog('play: roomCreateStub type=${type.name} (no WS)');
    }
  }

  Future<void> _runPostMatch() async {
    if (LOGGING_SWITCH) {
      customlog('play: postMatch stub');
    }
  }
}
