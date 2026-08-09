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
        MatchFlowPhase.inMatch => 'In match',
        MatchFlowPhase.postMatch => 'Post-match (stub)',
      };
}

class MatchFlowState {
  const MatchFlowState({
    this.phase = MatchFlowPhase.idle,
    this.selectedType,
    this.practiceLoadout,
    this.errorMessage,
  });

  final MatchFlowPhase phase;
  final MatchType? selectedType;
  final PracticeLoadout? practiceLoadout;

  /// Set when a play attempt aborts; UI shows an OK modal then [clearError].
  final String? errorMessage;

  bool get isIdle => phase == MatchFlowPhase.idle;

  MatchFlowState copyWith({
    MatchFlowPhase? phase,
    MatchType? selectedType,
    PracticeLoadout? practiceLoadout,
    String? errorMessage,
    bool clearSelectedType = false,
    bool clearPracticeLoadout = false,
    bool clearError = false,
  }) {
    return MatchFlowState(
      phase: phase ?? this.phase,
      selectedType: clearSelectedType
          ? null
          : (selectedType ?? this.selectedType),
      practiceLoadout: clearPracticeLoadout
          ? null
          : (practiceLoadout ?? this.practiceLoadout),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Practice loadout — one Arcori + one slammer (arena fixed locally).
class PracticeLoadout {
  const PracticeLoadout({
    required this.arcoriId,
    required this.slammerId,
  });

  final String arcoriId;
  final String slammerId;
}
