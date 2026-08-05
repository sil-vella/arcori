/// Match types and flow phases for the Play hub pipeline.
///
/// GDD aliases: practice → Practice; quickStart → Random Match;
/// specialEvent → Event Match; invite → Friend Match.
enum MatchType {
  practice,
  quickStart,
  specialEvent,
  invite,
}

extension MatchTypeLabel on MatchType {
  String get label => switch (this) {
        MatchType.practice => 'Practice',
        MatchType.quickStart => 'Quick Start',
        MatchType.specialEvent => 'Special Event',
        MatchType.invite => 'Invite',
      };
}

enum MatchFlowPhase {
  idle,
  selectingType,
  typeSetup,
  inMatch,
  postMatch,
}

extension MatchFlowPhaseLabel on MatchFlowPhase {
  String get label => switch (this) {
        MatchFlowPhase.idle => 'Ready',
        MatchFlowPhase.selectingType => 'Select match type',
        MatchFlowPhase.typeSetup => 'Setting up…',
        MatchFlowPhase.inMatch => 'Match (stub)',
        MatchFlowPhase.postMatch => 'Post-match (stub)',
      };
}

class MatchFlowState {
  const MatchFlowState({
    this.phase = MatchFlowPhase.idle,
    this.selectedType,
  });

  final MatchFlowPhase phase;
  final MatchType? selectedType;

  bool get isIdle => phase == MatchFlowPhase.idle;

  MatchFlowState copyWith({
    MatchFlowPhase? phase,
    MatchType? selectedType,
    bool clearSelectedType = false,
  }) {
    return MatchFlowState(
      phase: phase ?? this.phase,
      selectedType: clearSelectedType
          ? null
          : (selectedType ?? this.selectedType),
    );
  }
}
