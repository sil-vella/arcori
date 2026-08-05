import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/dev_logger.dart';
import 'play_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

final matchFlowProvider =
    NotifierProvider<MatchFlowNotifier, MatchFlowState>(MatchFlowNotifier.new);

/// Owns the Play → type select → setup → match → post-match pipeline.
///
/// Stage 1: stub hooks complete immediately. Later stages replace bodies and
/// may present match / post-match surfaces; flow still ends on Play idle.
class MatchFlowNotifier extends Notifier<MatchFlowState> {
  int _runId = 0;

  @override
  MatchFlowState build() => const MatchFlowState();

  /// Enter type selection. No-op if not idle.
  void startPlay() {
    if (!state.isIdle) return;
    _setPhase(MatchFlowPhase.selectingType);
  }

  /// Cancel type modal → idle.
  void cancelSelection() {
    if (state.phase != MatchFlowPhase.selectingType) return;
    _runId++;
    state = const MatchFlowState();
    if (LOGGING_SWITCH) {
      customlog('play: cancelSelection → idle');
    }
  }

  /// Chosen type → run stub pipeline → idle.
  Future<void> selectType(MatchType type) async {
    if (state.phase != MatchFlowPhase.selectingType) return;
    final runId = ++_runId;
    state = MatchFlowState(
      phase: MatchFlowPhase.typeSetup,
      selectedType: type,
    );
    if (LOGGING_SWITCH) {
      customlog('play: selectType=${type.name} → typeSetup');
    }

    await _runTypeSetup(type);
    if (!_isCurrentRun(runId, type)) return;

    _setPhase(MatchFlowPhase.inMatch);
    await _runMatchSsot();
    if (!_isCurrentRun(runId, type)) return;

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

  /// Hook: per-type setup (matchmaking, invite, event rules). Stage 1: no-op.
  Future<void> _runTypeSetup(MatchType type) async {
    if (LOGGING_SWITCH) {
      customlog('play: typeSetup stub type=${type.name}');
    }
  }

  /// Hook: SSOT core gameplay used by all types. Stage 1: no-op.
  Future<void> _runMatchSsot() async {
    if (LOGGING_SWITCH) {
      customlog('play: matchSsot stub');
    }
  }

  /// Hook: type-dependent post-match. Stage 1: no-op.
  Future<void> _runPostMatch() async {
    if (LOGGING_SWITCH) {
      customlog('play: postMatch stub');
    }
  }
}
