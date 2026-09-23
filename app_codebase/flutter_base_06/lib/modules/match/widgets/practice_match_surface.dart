import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/media_url.dart';
import '../../../core/modal/modal.dart';
import '../../../core/screen/screen.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/state/user/user_profile_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_visuals.dart';
import '../../../core/ws/ws_connection_manager.dart';
import '../../../utils/dev_logger.dart';
import '../input/match_grace.dart';
import '../input/slam_input_capture.dart';
import '../input/slam_input_models.dart';
import '../input/slam_motion_capability.dart';
import '../match_action_client.dart';
import '../practice_ai_pool.dart';
import '../state/match_notifier.dart';
import '../state/match_snapshot_state.dart';
import '../state/slam_motion_capability_provider.dart';
import '../../play/game_controls_prefs.dart';
import '../../play/play_models.dart';
import '../../play/play_notifier.dart';
import 'arcori_image_prefetch.dart';
import 'arcori_look.dart';
import 'arcori_stack_surface.dart';
import 'arena_pov_backdrop.dart';
import 'match_player_chrome.dart';
import 'slam_result_modal.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const _dartWsId = 'dart';

/// Match surface — Template 002 layout; gesture input on your turn.
Future<void> showPracticeMatchSurface(BuildContext context, WidgetRef ref) {
  return AppModal.showFullScreen<void>(
    context,
    barrierDismissible: false,
    builder: (ctx) => Theme(
      data: AppTheme.dark,
      child: const SizedBox.expand(
        child: AppFullScreenModal(
          title: null,
          showCloseButton: false,
          scrollable: false,
          padding: EdgeInsets.zero,
          child: _PracticeMatchBody(),
        ),
      ),
    ),
  );
}

class _PracticeMatchBody extends ConsumerStatefulWidget {
  const _PracticeMatchBody();

  @override
  ConsumerState<_PracticeMatchBody> createState() => _PracticeMatchBodyState();
}

class _PracticeMatchBodyState extends ConsumerState<_PracticeMatchBody> {
  Timer? _graceTicker;
  Map<String, dynamic>? _predictiveImpulse;
  Map<String, dynamic>? _pendingPredictiveImpulse;
  int? _lastSlamResultModalVersion;
  Map<String, dynamic>? _pendingSlamResultEvent;
  int _pendingSlamResultDelta = 0;
  SlamAim _liveAim = SlamAim.center;
  double? _powerPreview;
  String? _prefetchedArtFp;
  final _stackAreaKey = GlobalKey();
  final _stackPaintKey = GlobalKey();
  final _selfAvatarKey = GlobalKey();
  final _selfSlammerKey = GlobalKey();
  final _oppAvatarKeys = <GlobalKey>[GlobalKey(), GlobalKey()];
  final _oppSlammerKeys = <GlobalKey>[GlobalKey(), GlobalKey()];
  final _arenaPovScale = ValueNotifier<double>(1.0);

  /// Local pre-authority strike token (negative) so remount can skipStrike.
  int _localStrikeSeq = 0;
  int? _activeStrikeToken;
  bool _skipNextAuthorityStrike = false;
  ArcoriLook? _strikeLook;
  String? _strikeLottieUrl;
  Alignment _strikeFrom = Alignment.bottomCenter;
  Offset? _strikeHomeOffset;
  /// Seat whose arena anim owns the slammer (chrome rest hidden for that seat).
  String? _strikeAnimUserId;
  /// Monotonic claim id so stale remount/dispose cannot leave rest hidden.
  int _slammerHideGen = 0;
  int _slammerHideClaimGen = 0;
  /// Claim id handed to the live [ArcoriStackSurface] callback (captured per build).
  int? _stackSlammerHideClaim;
  /// Authority slam version already armed — ignore later snapshot echoes.
  int? _lastSlamStrikeArmedVersion;

  @override
  void dispose() {
    _graceTicker?.cancel();
    _arenaPovScale.dispose();
    _pendingSlamResultEvent = null;
    super.dispose();
  }

  bool _matchStillLive() {
    final snap = ref.read(matchSnapshotProvider);
    if (snap.isEnded) return false;
    final phase = ref.read(matchFlowProvider).phase;
    return phase == MatchFlowPhase.inMatch;
  }

  void _flushPendingSlamResultModal() {
    final event = _pendingSlamResultEvent;
    if (event == null || !mounted) return;
    if (!_matchStillLive()) {
      _pendingSlamResultEvent = null;
      if (LOGGING_SWITCH) {
        customlog('slamResultModal: drop pending (match not live)');
      }
      return;
    }
    _pendingSlamResultEvent = null;
    final delta = _pendingSlamResultDelta;
    showSlamResultModal(
      context,
      lastEvent: Map<String, dynamic>.from(event),
      actorScoreDelta: delta,
    );
  }

  void _onStackAnimComplete(int stackVersion) {
    final pending = _pendingSlamResultEvent;
    if (pending == null) return;
    final pendingVersion = pending['version'];
    if (pendingVersion is! int || pendingVersion != stackVersion) return;
    _flushPendingSlamResultModal();
  }

  /// Close this shell even when another modal is on top (post-match / lobby).
  void _forceCloseShell({required String reason}) {
    _pendingSlamResultEvent = null;
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    if (LOGGING_SWITCH) {
      customlog(
        'matchSurface: forceClose reason=$reason current=${route.isCurrent}',
      );
    }
    dismissModalRoute(context);
  }

  /// Close the match fullscreen once it is the top route (after slam overlays).
  void _scheduleMatchShellDismiss({int attempts = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        dismissModalRoute(context);
        return;
      }
      if (attempts >= 25) {
        _forceCloseShell(reason: 'ended-timeout');
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        final phase = ref.read(matchFlowProvider).phase;
        if (phase != MatchFlowPhase.inMatch) {
          _forceCloseShell(reason: 'phase=${phase.name}');
          return;
        }
        if (!ref.read(matchSnapshotProvider).isEnded) return;
        _scheduleMatchShellDismiss(attempts: attempts + 1);
      });
    });
  }

  void _syncGraceTicker(bool inGrace) {
    if (inGrace && _graceTicker == null) {
      _graceTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!inGrace && _graceTicker != null) {
      _graceTicker?.cancel();
      _graceTicker = null;
    }
  }

  bool _isLocal(String? matchId) =>
      matchId != null && matchId.startsWith('local_practice_');

  /// Human seat actor for input / turn checks.
  String? _humanActorUserId(MatchSnapshotState snap) {
    final authId = ref.read(authProvider).userId?.trim();
    if (authId != null && authId.isNotEmpty) {
      if (_mySeatIndex(snap, authId) != null) return authId;
    }
    if (!_isLocal(snap.matchId)) {
      return (authId != null && authId.isNotEmpty) ? authId : null;
    }
    for (final seat in snap.seats) {
      if (seat.kind == 'human' && seat.userId.isNotEmpty) return seat.userId;
    }
    final caller = snap.callerUserId?.trim() ?? '';
    return caller.isNotEmpty ? caller : null;
  }

  void _resetLiveAim(String reason) {
    if (_liveAim.x == 0 && _liveAim.z == 0 && _powerPreview == null) {
      return;
    }
    if (LOGGING_SWITCH) {
      customlog('matchSurface: resetAim reason=$reason');
    }
    setState(() {
      _liveAim = SlamAim.center;
      _powerPreview = null;
    });
  }

  int? _mySeatIndex(MatchSnapshotState snap, String? userId) {
    if (userId == null || userId.isEmpty) return null;
    for (final seat in snap.seats) {
      if (seat.userId == userId) return seat.seatIndex;
    }
    return null;
  }

  bool _isMyTurn(MatchSnapshotState snap, String? userId) {
    final active = snap.active?['seatIndex'];
    if (active is! int) return false;
    return _mySeatIndex(snap, userId) == active;
  }

  int _scoreFor(MatchSnapshotState snap, String userId) {
    for (final seat in snap.seats) {
      if (seat.userId == userId) return seat.score;
    }
    return 0;
  }

  bool _simHasFrames(Map<String, dynamic>? sim) {
    final frames = sim?['frames'];
    return frames is List && frames.length >= 2;
  }

  String _displayNameFor({
    required MatchSeatView seat,
    required bool isSelf,
  }) {
    if (isSelf) {
      final profileName =
          ref.read(userProfileProvider).profile?.username.trim() ?? '';
      if (profileName.isNotEmpty) return profileName;
    }
    final fromSeat = seat.username?.trim() ?? '';
    if (fromSeat.isNotEmpty) return fromSeat;
    if (seat.kind == 'ai') return practiceAiUsernameFor(seat.userId);
    final id = seat.userId.trim();
    if (id.isEmpty) return 'Player';
    return id.length <= 8 ? id : id.substring(0, 8);
  }

  String? _avatarUrlFor({
    required MatchSeatView seat,
    required bool isSelf,
  }) {
    if (isSelf) {
      final profileUrl = ref.read(userProfileProvider).profile?.avatarUrl;
      if (profileUrl != null && profileUrl.trim().isNotEmpty) {
        return profileUrl;
      }
    }
    final fromSeat = seat.avatarUrl?.trim() ?? '';
    return fromSeat.isNotEmpty ? fromSeat : null;
  }

  ArcoriLook? _slammerLookFor(MatchSeatView? seat) {
    if (seat == null) return null;
    final id = seat.slammerId.trim();
    if (id.isEmpty) return null;
    return ArcoriLook(
      designId: id,
      imageUrl: seat.imageUrl,
      colorHex: seat.color,
    );
  }

  Alignment _strikeFromFor({
    required MatchSeatView actor,
    required MatchSeatView? selfSeat,
    required List<MatchSeatView> opponents,
  }) {
    if (selfSeat != null && actor.userId == selfSeat.userId) {
      return const Alignment(0, 1.25);
    }
    if (opponents.length <= 1) {
      return const Alignment(0, -1.25);
    }
    final idx = opponents.indexWhere((o) => o.userId == actor.userId);
    if (idx <= 0) return const Alignment(-1.25, -0.5);
    return const Alignment(1.25, -0.5);
  }

  GlobalKey? _slammerKeyFor({
    required MatchSeatView actor,
    required MatchSeatView? selfSeat,
    required List<MatchSeatView> opponents,
  }) {
    if (selfSeat != null && actor.userId == selfSeat.userId) {
      return _selfSlammerKey;
    }
    final idx = opponents.indexWhere((o) => o.userId == actor.userId);
    if (idx < 0 || idx >= _oppSlammerKeys.length) return null;
    return _oppSlammerKeys[idx];
  }

  /// Pixel offset from stack center to the resting slammer disc center.
  Offset? _homeAtSlammerRest(
    GlobalKey slammerKey, {
    required bool stackAppliesFitZoom,
  }) {
    final slamCtx = slammerKey.currentContext;
    final stackCtx =
        _stackPaintKey.currentContext ?? _stackAreaKey.currentContext;
    if (slamCtx == null || stackCtx == null) return null;
    final slamBox = slamCtx.findRenderObject() as RenderBox?;
    final sBox = stackCtx.findRenderObject() as RenderBox?;
    if (slamBox == null ||
        sBox == null ||
        !slamBox.hasSize ||
        !sBox.hasSize) {
      return null;
    }

    final slamCenter = slamBox.localToGlobal(slamBox.size.center(Offset.zero));
    final restLocal = sBox.globalToLocal(slamCenter);
    var home = restLocal -
        Offset(sBox.size.width * 0.5, sBox.size.height * 0.5);
    // Internal fit-zoom scales paint but not this RenderBox — undo it.
    if (stackAppliesFitZoom) {
      final fit = _arenaPovScale.value;
      if (fit > 0.01) {
        home = Offset(home.dx / fit, home.dy / fit);
      }
    }
    return home;
  }

  Offset? _resolveStrikeHomeOffset({
    required MatchSeatView actor,
    required MatchSeatView? selfSeat,
    required List<MatchSeatView> opponents,
    required bool stackAppliesFitZoom,
  }) {
    final key = _slammerKeyFor(
      actor: actor,
      selfSeat: selfSeat,
      opponents: opponents,
    );
    if (key == null) return null;
    return _homeAtSlammerRest(
      key,
      stackAppliesFitZoom: stackAppliesFitZoom,
    );
  }

  void _scheduleStrikeHomeResolve({
    required MatchSeatView actor,
    required MatchSeatView? selfSeat,
    required List<MatchSeatView> opponents,
    required bool stackAppliesFitZoom,
  }) {
    void apply() {
      if (!mounted) return;
      final home = _resolveStrikeHomeOffset(
        actor: actor,
        selfSeat: selfSeat,
        opponents: opponents,
        stackAppliesFitZoom: stackAppliesFitZoom,
      );
      if (home == null) return;
      if (_strikeHomeOffset == home) return;
      setState(() => _strikeHomeOffset = home);
    }

    apply();
    WidgetsBinding.instance.addPostFrameCallback((_) => apply());
  }

  int _claimSlammerHide(String userId) {
    _slammerHideGen++;
    _slammerHideClaimGen = _slammerHideGen;
    _strikeAnimUserId = userId;
    _stackSlammerHideClaim = _slammerHideClaimGen;
    if (LOGGING_SWITCH) {
      customlog(
        'slammerHide: claim user=$userId gen=$_slammerHideClaimGen',
      );
    }
    return _slammerHideClaimGen;
  }

  void _clearSlammerHideFields() {
    _strikeAnimUserId = null;
    _stackSlammerHideClaim = null;
  }

  void _releaseSlammerHide({int? claimGen}) {
    if (claimGen != null && claimGen != _slammerHideClaimGen) {
      if (LOGGING_SWITCH) {
        customlog(
          'slammerHide: ignore stale release claim=$claimGen '
          'current=$_slammerHideClaimGen',
        );
      }
      return;
    }
    if (_strikeAnimUserId == null &&
        _stackSlammerHideClaim == null &&
        claimGen == null) {
      return;
    }
    if (LOGGING_SWITCH) {
      customlog(
        'slammerHide: release user=$_strikeAnimUserId claim=$claimGen',
      );
    }
    _clearSlammerHideFields();
    if (!mounted) return;
    setState(() {});
  }

  MatchSeatView? _seatByUserId(MatchSnapshotState snap, String? userId) {
    final uid = (userId ?? '').trim();
    if (uid.isEmpty) return null;
    for (final s in snap.seats) {
      if (s.userId == uid) return s;
    }
    return null;
  }

  Future<void> _commitSlam(SlamInputPayload payload) async {
    final snap = ref.read(matchSnapshotProvider);
    final matchId = snap.matchId;
    if (matchId == null || matchId.isEmpty || snap.isEnded) return;

    final userId = _humanActorUserId(snap);
    if (userId == null || userId.isEmpty) return;
    if (!_isMyTurn(snap, userId)) return;
    if (activeInputLocked(snap.active) || activeInGracePeriod(snap.active)) {
      return;
    }

    final input = payload.toJson();
    final traj = payload.trajectory ?? SlamTrajectory.fromAim(payload.aim);
    final me = _seatByUserId(snap, userId);
    final mySeatIdx = _mySeatIndex(snap, userId);
    final opponents = <MatchSeatView>[
      for (final s in snap.seats)
        if (mySeatIdx == null || s.seatIndex != mySeatIdx) s,
    ]..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));

    final token = --_localStrikeSeq;
    final look = _slammerLookFor(me);
    final actor = me ?? snap.seats.first;
    final stackAppliesFitZoom =
        resolveMediaUrl(snap.arenaImageUrl).isEmpty;
    final home = _resolveStrikeHomeOffset(
      actor: actor,
      selfSeat: me,
      opponents: opponents,
      stackAppliesFitZoom: stackAppliesFitZoom,
    );
    setState(() {
      _liveAim = payload.aim;
      _skipNextAuthorityStrike = false;
      _strikeLook = look;
      _strikeLottieUrl = me?.lottieUrl;
      _strikeFrom = _strikeFromFor(
        actor: actor,
        selfSeat: me,
        opponents: opponents,
      );
      _strikeHomeOffset = home;
      final impulse = {
        'vx': traj.dx * payload.speed,
        'vy': traj.dy * payload.speed,
        'spin': payload.speed * 1.5,
        'power': payload.speed,
      };
      if (look == null) {
        // No face art — skip strike gate, scatter immediately.
        _activeStrikeToken = token;
        _predictiveImpulse = impulse;
        _pendingPredictiveImpulse = null;
        _skipNextAuthorityStrike = true;
        _strikeAnimUserId = null;
        _stackSlammerHideClaim = null;
      } else {
        _predictiveImpulse = null;
        _pendingPredictiveImpulse = impulse;
        // Hide chrome rest + start arena only once dock coords are known.
        if (home != null) {
          _claimSlammerHide(actor.userId);
          _activeStrikeToken = token;
        }
      }
    });
    if (look != null && home == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final resolved = _resolveStrikeHomeOffset(
          actor: actor,
          selfSeat: me,
          opponents: opponents,
          stackAppliesFitZoom: stackAppliesFitZoom,
        );
        setState(() {
          _strikeHomeOffset = resolved;
          _claimSlammerHide(actor.userId);
          _activeStrikeToken = token;
        });
      });
    } else {
      _scheduleStrikeHomeResolve(
        actor: actor,
        selfSeat: me,
        opponents: opponents,
        stackAppliesFitZoom: stackAppliesFitZoom,
      );
    }

    if (_isLocal(matchId)) {
      await ref.read(matchSnapshotProvider.notifier).localSlam(
            actorUserId: userId,
            input: input,
          );
      return;
    }

    final manager = ref.read(wsConnectionManagerProvider.notifier);
    await sendMatchAction(
      manager: manager,
      matchId: matchId,
      action: 'slam',
      input: input,
    );
  }

  Future<void> _endOnline() async {
    final snap = ref.read(matchSnapshotProvider);
    final matchId = snap.matchId;
    if (matchId == null || matchId.isEmpty || snap.isEnded) return;
    final userId = ref.read(authProvider).userId?.trim();
    if (userId == null || userId.isEmpty || snap.callerUserId != userId) {
      return;
    }
    final manager = ref.read(wsConnectionManagerProvider.notifier);
    await manager.send(
      _dartWsId,
      type: 'event',
      channel: 'match/end',
      payload: {'matchId': matchId},
    );
  }

  void _precacheTableArt(MatchSnapshotState snap) {
    final urls = collectArcoriArtUrls(
      extra: [
        ...snap.pieces.map((p) => p.imageUrl),
        ...snap.pieces.map((p) => p.lottieUrl),
        ...snap.seats.map((s) => s.imageUrl),
        ...snap.seats.map((s) => s.lottieUrl),
        snap.arenaImageUrl,
      ],
    );
    final fp = urls.join('|');
    if (fp.isEmpty || fp == _prefetchedArtFp) return;
    _prefetchedArtFp = fp;
    unawaited(precacheArcoriArt(context, urls));
  }

  Widget? _turnOverlay({
    required MatchSnapshotState snap,
    required bool local,
    required bool inGrace,
    required bool inputLocked,
    required bool armed,
    required Duration? graceLeft,
    required SlamControlMode controlMode,
  }) {
    String? primary;
    String? secondary;
    if (inGrace) {
      primary = 'Get ready…';
      secondary = graceLeft != null && graceLeft.inSeconds > 0
          ? 'Match starts in ${graceLeft.inSeconds}s'
          : 'Match starting…';
    } else if (inputLocked) {
      primary = 'Resolving slam…';
      secondary = 'Wait for the table to settle';
    } else if (armed) {
      final shakeProbe = ref.watch(slamShakeAvailableProvider);
      final shakeAvailable = shakeProbe.value ?? false;
      final hints = slamTurnHints(
        shakeAvailable: shakeAvailable,
        controlMode: controlMode,
      );
      primary = hints.primary;
      secondary = hints.secondary;
    } else if (!snap.isEnded && snap.phase == 'playing') {
      primary = 'Waiting for other player…';
    }

    final showEnd = !local && !snap.isEnded;
    if (primary == null && !showEnd) return null;

    // Stack + IgnorePointer so hints never steal aim/touch from the playfield.
    final hud = context.appHud;
    return SafeArea(
      child: Stack(
        children: [
          if (primary != null)
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: IgnorePointer(
                child: Center(
                  child: AppHudGlassChip(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          primary,
                          style: context.appTypography.label.copyWith(
                            color: hud.onGlass,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (secondary != null) ...[
                          AppSpacing.gapXs,
                          Text(
                            secondary,
                            style: context.appTypography.bodySmall.copyWith(
                              color: hud.onGlassMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (showEnd)
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: Center(
                child: OutlinedButton(
                  style: context.appButtons.tertiary.outlined,
                  onPressed: _endOnline,
                  child: const Text('End match'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(matchSnapshotProvider);
    final local = _isLocal(snap.matchId);
    ref.watch(authProvider.select((a) => a.userId?.trim()));
    ref.watch(userProfileProvider.select((p) => p.profile?.username));
    ref.watch(userProfileProvider.select((p) => p.profile?.avatarUrl));
    final userId = _humanActorUserId(snap);
    final inGrace = activeInGracePeriod(snap.active);
    final inputLocked = activeInputLocked(snap.active);
    _syncGraceTicker(inGrace || inputLocked);
    final graceLeft = graceRemaining(snap.active);
    final myTurn = _isMyTurn(snap, userId);
    final armed = snap.phase == 'playing' &&
        !snap.isEnded &&
        myTurn &&
        !inGrace &&
        !inputLocked;
    final controlMode = ref.watch(gameControlsProvider).slamControlMode;
    _precacheTableArt(snap);

    ref.listen(matchSnapshotProvider, (prev, next) {
      if (next.isEnded && prev?.isEnded != true && context.mounted) {
        _pendingSlamResultEvent = null;
        _scheduleMatchShellDismiss();
      }

      final prevSeat = prev?.active?['seatIndex'];
      final nextSeat = next.active?['seatIndex'];
      final prevGrace = activeInGracePeriod(prev?.active);
      final nextGrace = activeInGracePeriod(next.active);
      final nextMe = _humanActorUserId(next);
      final nextMyTurn = _isMyTurn(next, nextMe);
      final nextArmed = next.phase == 'playing' &&
          !next.isEnded &&
          nextMyTurn &&
          !nextGrace &&
          !activeInputLocked(next.active);
      final prevArmed = prev != null &&
          prev.phase == 'playing' &&
          !prev.isEnded &&
          _isMyTurn(prev, _humanActorUserId(prev)) &&
          !prevGrace &&
          !activeInputLocked(prev.active);
      if (prev?.matchId != next.matchId ||
          prev?.round != next.round ||
          prevSeat != nextSeat ||
          (!prevArmed && nextArmed)) {
        if (LOGGING_SWITCH) {
          customlog(
            'matchSurface: aim→center armed=$nextArmed '
            'seat=$nextSeat mode=${ref.read(gameControlsProvider).slamControlMode.name}',
          );
        }
        _resetLiveAim(
          'match=${next.matchId} round=${next.round} seat=$nextSeat',
        );
        if (mounted) {
          setState(() => _liveAim = SlamAim.center);
        }
      }

      final event = next.lastEvent;
      if (event == null || event['type'] != 'slam') return;
      final version = event['version'];
      if (version is! int) return;

      final pending = _pendingSlamResultEvent;
      if (pending != null && pending['version'] != version) {
        _flushPendingSlamResultModal();
      }

      final outcome = event['outcome'];
      final hasSim = outcome is Map &&
          outcome['sim'] is Map &&
          _simHasFrames(Map<String, dynamic>.from(outcome['sim'] as Map));
      if (hasSim && _predictiveImpulse != null && mounted) {
        setState(() => _predictiveImpulse = null);
      }

      final input = event['input'];
      if (input is Map && input['speed'] is num && mounted) {
        if (_powerPreview != null) {
          setState(() => _powerPreview = null);
        }
      }

      final actorId = event['actorUserId']?.toString();
      final me = _humanActorUserId(next);
      final actorIsMe = me != null && me.isNotEmpty && actorId == me;
      // Local strike still in flight (negative token + chrome rest hidden).
      final localStrikeInFlight = _activeStrikeToken != null &&
          _activeStrikeToken! < 0 &&
          _strikeAnimUserId != null;

      // Turn advances / aim resets re-emit the same lastEvent — do not re-claim
      // hide or the resting slammer stays invisible until the next slam.
      if (_lastSlamStrikeArmedVersion == version) {
        return;
      }

      // Local already started a pre-authority strike — remount should skip the
      // strike beat. Do not re-hide chrome if local already released rest.
      if (actorIsMe && (localStrikeInFlight || _skipNextAuthorityStrike)) {
        if (mounted) {
          setState(() {
            _lastSlamStrikeArmedVersion = version;
            _skipNextAuthorityStrike = true;
            _activeStrikeToken = version;
            // Bump hide claim so the disposed stack's abort cannot clear us.
            if (localStrikeInFlight) {
              _claimSlammerHide(me);
            }
          });
        }
      } else {
        final actor = _seatByUserId(next, actorId);
        if (actor != null && mounted) {
          final mySeatIdx = _mySeatIndex(next, me);
          MatchSeatView? selfSeat;
          final opponents = <MatchSeatView>[];
          for (final s in next.seats) {
            if (mySeatIdx != null && s.seatIndex == mySeatIdx) {
              selfSeat = s;
            } else {
              opponents.add(s);
            }
          }
          opponents.sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
          final stackAppliesFitZoom =
              resolveMediaUrl(next.arenaImageUrl).isEmpty;
          final look = _slammerLookFor(actor);
          final home = _resolveStrikeHomeOffset(
            actor: actor,
            selfSeat: selfSeat,
            opponents: opponents,
            stackAppliesFitZoom: stackAppliesFitZoom,
          );
          setState(() {
            _lastSlamStrikeArmedVersion = version;
            _skipNextAuthorityStrike = false;
            _strikeLook = look;
            _strikeLottieUrl = actor.lottieUrl;
            _strikeFrom = _strikeFromFor(
              actor: actor,
              selfSeat: selfSeat,
              opponents: opponents,
            );
            _strikeHomeOffset = home;
            if (look == null) {
              _activeStrikeToken = version;
              _clearSlammerHideFields();
            } else if (home != null) {
              _claimSlammerHide(actor.userId);
              _activeStrikeToken = version;
            } else {
              // Keep rest visible until dock resolves next frame.
              _clearSlammerHideFields();
            }
          });
          if (look != null && home == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              // Superseded slam or already restored — never re-hide at rest.
              if (_lastSlamStrikeArmedVersion != version) return;
              if (_strikeAnimUserId != null) return;
              if (_activeStrikeToken != version) return;
              final resolved = _resolveStrikeHomeOffset(
                actor: actor,
                selfSeat: selfSeat,
                opponents: opponents,
                stackAppliesFitZoom: stackAppliesFitZoom,
              );
              setState(() {
                _strikeHomeOffset = resolved;
                _claimSlammerHide(actor.userId);
                _activeStrikeToken = version;
              });
            });
          } else {
            _scheduleStrikeHomeResolve(
              actor: actor,
              selfSeat: selfSeat,
              opponents: opponents,
              stackAppliesFitZoom: stackAppliesFitZoom,
            );
          }
        }
      }

      if (me == null || me.isEmpty || actorId != me) return;
      if (_lastSlamResultModalVersion == version) return;

      _lastSlamResultModalVersion = version;
      final delta =
          prev == null ? 0 : _scoreFor(next, me) - _scoreFor(prev, me);
      _pendingSlamResultEvent = Map<String, dynamic>.from(event);
      _pendingSlamResultDelta = delta;
      if (LOGGING_SWITCH) {
        customlog(
          'slamResultModal: pending after anim version=$version '
          'result=${event['result']}',
        );
      }
    });

    ref.listen(matchFlowProvider, (prev, next) {
      if (prev?.phase != MatchFlowPhase.inMatch) return;
      if (next.phase == MatchFlowPhase.inMatch) return;
      _forceCloseShell(reason: 'flow=${next.phase.name}');
    });

    final lastEvent = snap.lastEvent;
    final outcome = lastEvent?['outcome'];
    final authorityImpulse = outcome is Map && outcome['impulse'] is Map
        ? Map<String, dynamic>.from(outcome['impulse'] as Map)
        : null;
    final authoritySim = outcome is Map && outcome['sim'] is Map
        ? Map<String, dynamic>.from(outcome['sim'] as Map)
        : null;
    final simReady = _simHasFrames(authoritySim);
    final stackImpulse =
        simReady ? null : (authorityImpulse ?? _predictiveImpulse);

    final stackKey = ValueKey(
      'stack-${snap.matchId}-s${(lastEvent != null && lastEvent['type'] == 'slam') ? lastEvent['version'] : 0}',
    );

    final mySeatIdx = _mySeatIndex(snap, userId);
    MatchSeatView? selfSeat;
    final opponents = <MatchSeatView>[];
    for (final seat in snap.seats) {
      if (mySeatIdx != null && seat.seatIndex == mySeatIdx) {
        selfSeat = seat;
      } else {
        opponents.add(seat);
      }
    }
    opponents.sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
    selfSeat ??= snap.seats.isNotEmpty ? snap.seats.first : null;

    final activeSeat = snap.active?['seatIndex'];

    return SlamInputCapture(
      key: ValueKey(
        'slam-${snap.matchId}-r${snap.round}-'
        's${snap.active?['seatIndex']}-'
        '${inGrace ? 'grace' : 'live'}-${controlMode.name}',
      ),
      armed: armed,
      controlMode: controlMode,
      onAimChanged: (aim) {
        if (!mounted) return;
        if ((_liveAim.x - aim.x).abs() < 1e-9 &&
            (_liveAim.z - aim.z).abs() < 1e-9) {
          return;
        }
        setState(() => _liveAim = aim);
      },
      onPowerPreview: (p) {
        if (!mounted) return;
        if (_powerPreview == p) return;
        setState(() => _powerPreview = p);
      },
      onCommit: (payload) => unawaited(_commitSlam(payload)),
      builder: (context, handle) {
        final arenaUrl = resolveMediaUrl(snap.arenaImageUrl);
        final hasArena = arenaUrl.isNotEmpty;
        // Capture hide claim for THIS stack instance — dispose must not release
        // a newer claim after remount bumped the gen.
        final slammerHideClaimAtBuild = _stackSlammerHideClaim;
        // Same camera contract as pre-refactor: with arena mural, stack paints
        // inside ArenaPovBackdrop (applyFitZoom off); aim hits the 220px slot.
        final stack = KeyedSubtree(
          key: _stackPaintKey,
          child: ArcoriStackSurface(
            key: stackKey,
            pieces: snap.pieces,
            impulse: stackImpulse,
            sim: authoritySim,
            showAimMarker: armed,
            aimX: _liveAim.x,
            aimZ: _liveAim.z,
            applyFitZoom: !hasArena,
            strikeLook: _strikeLook,
            strikeLottieUrl: _strikeLottieUrl,
            strikeFrom: _strikeFrom,
            strikeHomeOffset: _strikeHomeOffset,
            strikeToken: _activeStrikeToken,
            skipStrike: _skipNextAuthorityStrike &&
                lastEvent != null &&
                lastEvent['type'] == 'slam' &&
                _activeStrikeToken == lastEvent['version'],
            // After chrome rest was released, don't paint a second arena disc
            // on authority remount (avoids double + stuck-hide races).
            suppressArenaSlammer: _strikeAnimUserId == null,
            onStrikeComplete: () {
              if (!mounted) return;
              final pending = _pendingPredictiveImpulse;
              if (pending != null) {
                setState(() {
                  _predictiveImpulse = pending;
                  _pendingPredictiveImpulse = null;
                  _skipNextAuthorityStrike = true;
                });
              }
            },
            onPovScale: (fit) {
              if ((_arenaPovScale.value - fit).abs() < 0.002) return;
              _arenaPovScale.value = fit;
            },
            onSlammerAnimEnded: () {
              _releaseSlammerHide(claimGen: slammerHideClaimAtBuild);
            },
            onAnimComplete: () {
              final v = (lastEvent != null &&
                      lastEvent['type'] == 'slam' &&
                      lastEvent['version'] is int)
                  ? lastEvent['version'] as int
                  : snap.version;
              if (mounted) {
                setState(() {
                  _skipNextAuthorityStrike = false;
                  _pendingPredictiveImpulse = null;
                  // Drop local negative token so authority does not treat us
                  // as still in pre-strike after rest was restored.
                  if (_activeStrikeToken != null &&
                      _activeStrikeToken! < 0) {
                    _activeStrikeToken = null;
                  }
                });
              }
              _onStackAnimComplete(v);
            },
          ),
        );

        final locked = handle.aimLocked;
        // Unlocked: Listener for absolute aim. Locked: GestureDetector alone
        // for swipe (Listener+GestureDetector parent/child breaks drag arena).
        Widget? aimOverlay;
        if (controlMode == SlamControlMode.touch) {
          aimOverlay = Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final area = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                if (!armed) {
                  return const SizedBox.expand();
                }
                if (locked) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) {
                      if (LOGGING_SWITCH) {
                        customlog('matchSurface: swipe start (locked)');
                      }
                    },
                    onVerticalDragUpdate: handle.onPowerDragUpdate,
                    onVerticalDragEnd: (d) {
                      if (LOGGING_SWITCH) {
                        customlog(
                          'matchSurface: swipe end '
                          'vy=${d.primaryVelocity?.toStringAsFixed(0)}',
                        );
                      }
                      handle.onPowerDragEnd(d);
                    },
                    child: const SizedBox.expand(),
                  );
                }
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    if (LOGGING_SWITCH) {
                      customlog(
                        'matchSurface: aim down '
                        'local=${e.localPosition.dx.toStringAsFixed(0)},'
                        '${e.localPosition.dy.toStringAsFixed(0)} '
                        'area=${area.width.toStringAsFixed(0)}x'
                        '${area.height.toStringAsFixed(0)}',
                      );
                    }
                    handle.onAimAtLocal(e.localPosition, area);
                  },
                  onPointerMove: (e) =>
                      handle.onAimAtLocal(e.localPosition, area),
                  child: const SizedBox.expand(),
                );
              },
            ),
          );
        }

        // Hit-slot only: stack visuals live in ArenaPov when hasArena.
        final playfield = Stack(
          clipBehavior: Clip.none,
          children: [
            if (!hasArena) Positioned.fill(child: stack),
            if (aimOverlay != null) aimOverlay,
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(child: handle.aimLockButton()),
            ),
          ],
        );

        final animUid = _strikeAnimUserId;
        final selfChrome = selfSeat == null
            ? const SizedBox.shrink()
            : MatchPlayerChrome(
                username: _displayNameFor(seat: selfSeat, isSelf: true),
                avatarUrl: _avatarUrlFor(seat: selfSeat, isSelf: true),
                isSelf: true,
                isActive: activeSeat == selfSeat.seatIndex,
                avatarKey: _selfAvatarKey,
                slammerKey: _selfSlammerKey,
                slammerLook: _slammerLookFor(selfSeat),
                slammerLottieUrl: selfSeat.lottieUrl,
                showSlammer:
                    animUid == null || animUid != selfSeat.userId,
                slammerDock: MatchPlayerChrome.dockSelf,
              );

        final oppChrome = [
          for (var i = 0; i < opponents.length; i++)
            MatchPlayerChrome(
              username: _displayNameFor(seat: opponents[i], isSelf: false),
              avatarUrl: _avatarUrlFor(seat: opponents[i], isSelf: false),
              isActive: activeSeat == opponents[i].seatIndex,
              avatarKey: i < _oppAvatarKeys.length ? _oppAvatarKeys[i] : null,
              slammerKey:
                  i < _oppSlammerKeys.length ? _oppSlammerKeys[i] : null,
              slammerLook: _slammerLookFor(opponents[i]),
              slammerLottieUrl: opponents[i].lottieUrl,
              showSlammer:
                  animUid == null || animUid != opponents[i].userId,
              slammerDock: opponents.length <= 1
                  ? MatchPlayerChrome.dockOpponentTop
                  : (i == 0
                      ? MatchPlayerChrome.dockOpponentLeft
                      : MatchPlayerChrome.dockOpponentRight),
            ),
        ];

        return ScrollConfiguration(
          behavior: const _MatchNoScrollBehavior(),
          child: AppScreenTemplate002(
            stackAreaKey: _stackAreaKey,
            arenaLayer: hasArena
                ? ArenaPovBackdrop(
                    imageUrl: arenaUrl,
                    povScale: _arenaPovScale,
                    stackAreaKey: _stackAreaKey,
                    stackLayer: stack,
                  )
                : null,
            backgroundNetworkUrl:
                (!hasArena && arenaUrl.isNotEmpty) ? arenaUrl : null,
            self: selfChrome,
            opponents: oppChrome,
            center: playfield,
            overlay: _turnOverlay(
              snap: snap,
              local: local,
              inGrace: inGrace,
              inputLocked: inputLocked,
              armed: armed,
              graceLeft: graceLeft,
              controlMode: controlMode,
            ),
          ),
        );
      },
    );
  }
}

/// Match gestures must not lose to overscroll / parent scrollables.
class _MatchNoScrollBehavior extends ScrollBehavior {
  const _MatchNoScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const NeverScrollableScrollPhysics();
}
