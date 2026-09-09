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

/// How the player leaves the post-match screen.
enum PostMatchExitAction {
  done,
  playNew,
  rematch,
}

extension MatchFlowPhaseLabel on MatchFlowPhase {
  String get label => switch (this) {
        MatchFlowPhase.idle => 'Ready',
        MatchFlowPhase.selectingType => 'Select match type',
        MatchFlowPhase.typeSetup => 'Setting up…',
        MatchFlowPhase.inMatch => 'In match',
        MatchFlowPhase.postMatch => 'Post-match',
      };
}

class MatchFlowState {
  const MatchFlowState({
    this.phase = MatchFlowPhase.idle,
    this.selectedType,
    this.practiceLoadout,
    this.errorMessage,
    this.postMatchSoftError,
  });

  final MatchFlowPhase phase;
  final MatchType? selectedType;
  final PracticeLoadout? practiceLoadout;

  /// Set when a play attempt aborts; UI shows an OK modal then [clearError].
  final String? errorMessage;

  /// Soft finalize / post-match message (does not abort the pipeline).
  final String? postMatchSoftError;

  bool get isIdle => phase == MatchFlowPhase.idle;

  MatchFlowState copyWith({
    MatchFlowPhase? phase,
    MatchType? selectedType,
    PracticeLoadout? practiceLoadout,
    String? errorMessage,
    String? postMatchSoftError,
    bool clearSelectedType = false,
    bool clearPracticeLoadout = false,
    bool clearError = false,
    bool clearPostMatchSoftError = false,
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
      postMatchSoftError: clearPostMatchSoftError
          ? null
          : (postMatchSoftError ?? this.postMatchSoftError),
    );
  }
}

/// Result of host-side invite setup (invite id + invited user for matchmaking).
class InviteSetupResult {
  const InviteSetupResult({
    required this.inviteId,
    required this.invitedUserId,
  });

  final String inviteId;
  final String invitedUserId;
}

/// Captured from an ended online match for rematch invite + lobby find.
class RematchHostContext {
  const RematchHostContext({
    required this.priorMatchId,
    required this.seriesId,
    required this.seriesIndex,
    required this.otherHumanIds,
    required this.priorAiUserIds,
    required this.rematchSeats,
    required this.rematchTargetSeats,
  });

  final String priorMatchId;
  final String seriesId;
  final int seriesIndex;
  final List<String> otherHumanIds;
  final List<String> priorAiUserIds;
  final List<Map<String, dynamic>> rematchSeats;
  final int rematchTargetSeats;

  bool get canRematch =>
      seriesId.isNotEmpty &&
      (otherHumanIds.isNotEmpty || priorAiUserIds.isNotEmpty);
}

/// Practice loadout — slammer chosen in setup; Arcori auto-assigned.
class PracticeLoadout {
  const PracticeLoadout({
    required this.arcoriId,
    required this.slammerId,
    this.arcoriImageUrl,
    this.arcoriColor,
  });

  final String arcoriId;
  final String slammerId;
  final String? arcoriImageUrl;
  final String? arcoriColor;
}
