import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../../../utils/dev_logger.dart';
import '../../../core/theme/theme.dart';
import '../state/match_snapshot_state.dart';
import '../input/slam_input_models.dart';
import '../input/slam_physics_world.dart';
import '../input/turn_pacing.dart';
import 'arcori_disc.dart' show ArcoriDisc, faceUpFromQuat;
import 'arcori_look.dart';
import 'arena_pov_backdrop.dart';
import 'match_player_chrome.dart';
import 'slammer_strike_overlay.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Face-down Arcori stack — replays 3D xyzq pose timeline, or spring fallback.
class ArcoriStackSurface extends StatefulWidget {
  const ArcoriStackSurface({
    super.key,
    required this.pieces,
    this.impulse,
    this.sim,
    this.height = 220,
    this.onAnimComplete,
    this.showAimMarker = false,
    this.aimX = 0,
    this.aimZ = 0,
    this.onPovScale,
    this.applyFitZoom = true,
    this.worldScale = 1.0,
    this.strikeLook,
    this.strikeLottieUrl,
    this.strikeFrom = Alignment.bottomCenter,
    this.strikeHomeOffset,
    this.strikeToken,
    this.skipStrike = false,
    this.suppressArenaSlammer = false,
    this.onStrikeComplete,
    this.onSlammerAnimEnded,
  });

  final List<MatchPieceView> pieces;
  final Map<String, dynamic>? impulse;
  final Map<String, dynamic>? sim;
  final double height;

  /// Fired once when sim replay (or impulse fallback) finishes.
  final VoidCallback? onAnimComplete;

  /// Live hit marker while the local seat is armed.
  final bool showAimMarker;
  final double aimX;
  final double aimZ;

  /// Stack camera scale (1 = rest, lower = zoomed out to keep discs on screen).
  final ValueChanged<double>? onPovScale;

  /// When false, parent (arena camera) owns zoom; this widget still emits [onPovScale].
  final bool applyFitZoom;

  /// Extra paint scale before the parent camera. Arena path leaves this at 1
  /// so discs are drawn at rest Ø (scaling them down then up pixelates rims).
  final double worldScale;

  /// Equipped slammer look for the pre-scatter strike beat.
  final ArcoriLook? strikeLook;
  final String? strikeLottieUrl;
  final Alignment strikeFrom;

  /// Pixel offset from stack center to rest beside the acting player's avatar
  /// (toward the board). When null, falls back to [strikeFrom] alignment.
  final Offset? strikeHomeOffset;

  /// When [strikeToken] changes, play strike before sim/impulse (unless [skipStrike]).
  final int? strikeToken;
  final bool skipStrike;

  /// When true, never paint the arena slammer (chrome rest owns the disc).
  final bool suppressArenaSlammer;
  final VoidCallback? onStrikeComplete;

  /// Fired when the arena slammer finishes return-home, or is aborted (dispose).
  final VoidCallback? onSlammerAnimEnded;

  @override
  State<ArcoriStackSurface> createState() => _ArcoriStackSurfaceState();
}

class _ArcoriStackSurfaceState extends State<ArcoriStackSurface>
    with TickerProviderStateMixin {
  late final AnimationController _scatter;
  late final AnimationController _flip;
  late final AnimationController _simClock;
  late final AnimationController _returnClock;

  final Map<String, Offset> _offsets = {};
  final Map<String, _Quat> _quats = {};
  List<MatchPieceView> _pieces = const [];
  int _impulseNonce = 0;
  bool _replayingSim = false;
  bool _returningHome = false;
  List<_SimFrame> _simFrames = const [];
  double _pxPerMeter = 80;
  double _simDurationSec = 1.0;
  double? _lastEmittedPovScale;
  final Map<String, _Vec3> _restWorld = {};
  Timer? _settleHoldTimer;
  /// Fingerprint of the sim currently playing / last finished — skip restarts.
  String? _simFingerprint;
  /// Strike tokens already completed (skip re-strike when sim replaces predictive).
  final Set<int> _struckTokens = {};
  bool _awaitingStrike = false;
  int? _activeStrikeToken;

  // --- Slammer arena pose (scatter + return) ---
  SlammerArenaPhase _slammerPhase = SlammerArenaPhase.atHome;
  Offset _slammerOffset = Offset.zero;
  _Quat _slammerQuat = _Quat.faceUp();
  bool _slammerFaceUp = true;
  Offset _slammerScatterTarget = Offset.zero;
  bool _slammerScatterFaceUp = true;
  double _slammerScatterSpin = 0;
  Offset _slammerReturnFrom = Offset.zero;
  _Quat _slammerReturnFromQuat = _Quat.faceUp();
  final Map<String, Offset> _returnFromOffsets = {};
  final Map<String, _Quat> _returnFromQuats = {};
  Size _arenaSize = Size.zero;

  bool get _simReady {
    final frames = _parseSimFrames(widget.sim);
    return frames.length >= 2;
  }

  bool get _shouldStrike {
    final token = widget.strikeToken;
    if (token == null) return false;
    if (widget.skipStrike) return false;
    if (widget.strikeLook == null) return false;
    if (_struckTokens.contains(token)) return false;
    return true;
  }

  bool get _showSlammer =>
      !widget.suppressArenaSlammer &&
      widget.strikeLook != null &&
      widget.strikeToken != null &&
      (_awaitingStrike ||
          _slammerPhase == SlammerArenaPhase.flyIn ||
          _slammerPhase == SlammerArenaPhase.scatter ||
          _slammerPhase == SlammerArenaPhase.returnHome);

  String? _fingerprintSim(Map<String, dynamic>? sim) {
    if (sim == null) return null;
    final frames = sim['frames'];
    final steps = sim['steps'];
    final n = frames is List ? frames.length : 0;
    if (n < 2) return null;
    // First/last frame ids + steps — stable across Map.from rebuilds.
    final first = frames!.first;
    final last = frames.last;
    return 's=$steps;n=$n;a=${first.toString()};b=${last.toString()}';
  }

  @override
  void initState() {
    super.initState();
    _scatter = AnimationController.unbounded(vsync: this);
    _flip = AnimationController.unbounded(vsync: this);
    _simClock = AnimationController(vsync: this);
    _returnClock = AnimationController(vsync: this);
    _pieces = List<MatchPieceView>.from(widget.pieces);
    _syncRest(_pieces);
    _scatter.addListener(_onTick);
    _flip.addListener(_onTick);
    _simClock.addListener(_onSimTick);
    _returnClock.addListener(_onReturnTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _beginSlamMotion();
    });
  }

  @override
  void didUpdateWidget(covariant ArcoriStackSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final piecesChanged = !_samePieces(oldWidget.pieces, widget.pieces);
    if (piecesChanged) {
      _pieces = List<MatchPieceView>.from(widget.pieces);
      if (!_replayingSim && !_awaitingStrike && !_returningHome) {
        _snapPiecesToAuthority();
      }
    }

    final tokenChanged = oldWidget.strikeToken != widget.strikeToken;
    if (tokenChanged && widget.strikeToken != null) {
      _prepareSlammerForToken(widget.strikeToken!);
    }

    final nextFp = _fingerprintSim(widget.sim);
    final simChanged = nextFp != null && nextFp != _simFingerprint;
    if (tokenChanged || simChanged) {
      if (simChanged && _simReady) {
        _impulseNonce++;
      }
      _beginSlamMotion(forceSim: simChanged && _simReady);
      return;
    }

    if (!_simReady &&
        !_impulsesEqual(widget.impulse, oldWidget.impulse) &&
        widget.impulse != null &&
        !_replayingSim &&
        !_awaitingStrike &&
        !_returningHome) {
      _impulseNonce++;
      _runImpulse(widget.impulse!);
    }
  }

  void _prepareSlammerForToken(int token) {
    final plan = slammerScatterPlan(
      token: token,
      power: 0.55,
      vx: 0.4,
      vy: 0.6,
    );
    _slammerScatterTarget = plan.offset;
    _slammerScatterFaceUp = plan.faceUp;
    _slammerScatterSpin = plan.spin;
    if (_shouldStrike) {
      _slammerPhase = SlammerArenaPhase.flyIn;
    } else if (widget.skipStrike || _struckTokens.contains(token)) {
      _slammerPhase = SlammerArenaPhase.scatter;
      _slammerOffset = _impactOffsetPx();
      _slammerQuat = _Quat.faceUp();
      _slammerFaceUp = true;
    }
  }

  void _beginSlamMotion({bool forceSim = false}) {
    if (_shouldStrike) {
      final token = widget.strikeToken!;
      if (_awaitingStrike && _activeStrikeToken == token) return;
      if (LOGGING_SWITCH) {
        customlog(
          'arcoriStack: strike start token=$token '
          'from=${widget.strikeFrom} before=${_simReady ? 'sim' : 'impulse'}',
        );
      }
      _prepareSlammerForToken(token);
      setState(() {
        _awaitingStrike = true;
        _activeStrikeToken = token;
        _slammerPhase = SlammerArenaPhase.flyIn;
      });
      return;
    }

    final wantsMotion = _simReady || widget.impulse != null;
    if (!wantsMotion && !forceSim) return;
    _startMotionAfterStrike(forceSim: forceSim);
  }

  void _onStrikeComplete() {
    final token = widget.strikeToken;
    if (token != null) {
      _struckTokens.add(token);
    }
    if (LOGGING_SWITCH) {
      customlog('arcoriStack: strike complete token=$token → scatter');
    }
    widget.onStrikeComplete?.call();
    if (!mounted) return;
    setState(() {
      _awaitingStrike = false;
      _activeStrikeToken = null;
      _slammerPhase = SlammerArenaPhase.scatter;
      _slammerOffset = _impactOffsetPx();
      _slammerQuat = _Quat.faceUp();
      _slammerFaceUp = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startMotionAfterStrike(forceSim: _simReady);
    });
  }

  Offset _impactOffsetPx() {
    final impactX = (widget.aimX * 0.35).clamp(-0.35, 0.35);
    final impactY = (widget.aimZ * 0.35).clamp(-0.35, 0.35);
    final w = _arenaSize.width > 0 ? _arenaSize.width : 280.0;
    final h = _arenaSize.height > 0 ? _arenaSize.height : widget.height;
    return Offset(impactX * w * 0.5, impactY * h * 0.5);
  }

  Offset _homeOffsetPx() {
    final explicit = widget.strikeHomeOffset;
    if (explicit != null) return explicit;
    final a = widget.strikeFrom;
    final w = _arenaSize.width > 0 ? _arenaSize.width : 280.0;
    final h = _arenaSize.height > 0 ? _arenaSize.height : widget.height;
    return Offset(a.x * w * 0.5, a.y * h * 0.5);
  }

  void _startMotionAfterStrike({required bool forceSim}) {
    if (_awaitingStrike) return;
    if (_simReady) {
      _startSimIfPossible(force: true);
      return;
    }
    if (widget.impulse != null && !_replayingSim && !_returningHome) {
      _runImpulse(widget.impulse!);
    }
  }

  void _startSimIfPossible({required bool force}) {
    final frames = _parseSimFrames(widget.sim);
    if (frames.length < 2) return;
    final fp = _fingerprintSim(widget.sim);
    if (fp != null && fp == _simFingerprint) return;
    if (!force && _replayingSim) return;
    _runSim(widget.sim!, frames);
  }

  bool _samePieces(List<MatchPieceView> a, List<MatchPieceView> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].pieceId != b[i].pieceId || a[i].faceUp != b[i].faceUp) {
        return false;
      }
    }
    return true;
  }

  void _syncRest(List<MatchPieceView> pieces) {
    for (final p in pieces) {
      _offsets[p.pieceId] ??= Offset.zero;
      final cur = _quats[p.pieceId];
      if (cur == null) {
        _quats[p.pieceId] = p.faceUp ? _Quat.faceUp() : _Quat.faceDown();
      } else if (!_replayingSim) {
        _quats[p.pieceId] = _restingQuat(cur, p.faceUp);
      }
    }
  }

  bool _restFaceUp(MatchPieceView p, _Quat cur) {
    return p.faceUp || faceUpFromQuat(cur.x, cur.y, cur.z, cur.w);
  }

  void _flattenLiveQuatsToRest() {
    for (final p in widget.pieces) {
      final cur = _quats[p.pieceId] ??
          (p.faceUp ? _Quat.faceUp() : _Quat.faceDown());
      _quats[p.pieceId] = _restingQuat(cur, _restFaceUp(p, cur));
    }
  }

  void _onTick() {
    if (!_replayingSim &&
        !_returningHome &&
        _slammerPhase == SlammerArenaPhase.scatter) {
      _applySlammerScatterProgress(_scatter.value.clamp(0.0, 1.0));
    }
    if (mounted) setState(() {});
  }

  void _onSimTick() {
    if (!_replayingSim || _simFrames.isEmpty) return;
    final dt = widget.sim?['dt'] is num
        ? (widget.sim!['dt'] as num).toDouble()
        : 1.0 / 60.0;
    final time = _simClock.value * _simDurationSec;
    _applySimAt(time, dt);
    _applySlammerScatterProgress(_simClock.value.clamp(0.0, 1.0));
    if (mounted) setState(() {});
  }

  void _onReturnTick() {
    if (!_returningHome) return;
    final u = Curves.easeInOutCubic.transform(_returnClock.value.clamp(0.0, 1.0));
    final sorted = List<MatchPieceView>.from(_pieces)
      ..sort((a, b) => a.stackIndex.compareTo(b.stackIndex));
    const restStackGap = 2.0;
    for (var i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      final from = _returnFromOffsets[p.pieceId] ?? Offset.zero;
      final to = Offset(0, -i * restStackGap);
      _offsets[p.pieceId] = Offset.lerp(from, to, u)!;
      final qFrom = _returnFromQuats[p.pieceId] ?? _Quat.faceDown();
      final qTo = _restingQuat(qFrom, false);
      _quats[p.pieceId] = _nlerp(qFrom, qTo, u);
    }
    final home = _homeOffsetPx();
    _slammerOffset = Offset.lerp(_slammerReturnFrom, home, u)!;
    final yaw = home.distance < 1e-3 ? 0.0 : atan2(-home.dx, -home.dy);
    final endQ = slammerRestQuat(faceUp: true, yaw: yaw);
    final qHome = _Quat(endQ.x, endQ.y, endQ.z, endQ.w);
    _slammerQuat = _nlerp(_slammerReturnFromQuat, qHome, u);
    _slammerFaceUp = faceUpFromQuat(
      _slammerQuat.x,
      _slammerQuat.y,
      _slammerQuat.z,
      _slammerQuat.w,
    );
    if (mounted) setState(() {});
  }

  void _applySlammerScatterProgress(double u) {
    if (_slammerPhase != SlammerArenaPhase.scatter) return;
    final start = _impactOffsetPx();
    final t = Curves.easeOutCubic.transform(u.clamp(0.0, 1.0));
    _slammerOffset = Offset.lerp(start, _slammerScatterTarget, t)!;
    final spin = _slammerScatterSpin * t;
    final endQ = slammerRestQuat(faceUp: _slammerScatterFaceUp, yaw: spin);
    final startQ = Quaternion(0, 0, 0, 1);
    final mixed = _nlerpQuat(startQ, endQ, t);
    // Mid-flight tumble: blend in a tip so face reads mid-roll.
    final tip = min(1.0, sin(t * pi) * 1.15);
    final tipQ = Quaternion.axisAngle(Vector3(1, 0.35, 0.15), tip * (pi * 0.55));
    final live = (tipQ * mixed)..normalize();
    _slammerQuat = _Quat(live.x, live.y, live.z, live.w);
    _slammerFaceUp = faceUpFromQuat(live.x, live.y, live.z, live.w);
  }

  Quaternion _nlerpQuat(Quaternion a, Quaternion b, double t) {
    var bx = b.x, by = b.y, bz = b.z, bw = b.w;
    if (a.x * bx + a.y * by + a.z * bz + a.w * bw < 0) {
      bx = -bx;
      by = -by;
      bz = -bz;
      bw = -bw;
    }
    final x = a.x + (bx - a.x) * t;
    final y = a.y + (by - a.y) * t;
    final z = a.z + (bz - a.z) * t;
    final w = a.w + (bw - a.w) * t;
    return Quaternion(x, y, z, w)..normalize();
  }

  void _runSim(Map<String, dynamic> sim, List<_SimFrame> frames) {
    _settleHoldTimer?.cancel();
    _settleHoldTimer = null;
    _returnClock.stop();
    _returningHome = false;
    _replayingSim = true;
    _simFingerprint = _fingerprintSim(sim);
    _simFrames = frames;
    _pxPerMeter = sim['pxPerMeter'] is num
        ? (sim['pxPerMeter'] as num).toDouble()
        : 80.0;
    _restWorld.clear();
    for (final pose in frames.first.poses) {
      _restWorld[pose.id] = _Vec3(pose.x, pose.y, pose.z);
      _quats[pose.id] = _Quat(pose.qx, pose.qy, pose.qz, pose.qw);
      _offsets[pose.id] = Offset.zero;
    }

    // Refresh scatter plan from live impulse power when available.
    final power = widget.impulse?['power'] is num
        ? (widget.impulse!['power'] as num).toDouble()
        : (sim['frames'] != null ? 0.55 : 0.55);
    final vx = widget.impulse?['vx'] is num
        ? (widget.impulse!['vx'] as num).toDouble()
        : 0.35;
    final vy = widget.impulse?['vy'] is num
        ? (widget.impulse!['vy'] as num).toDouble()
        : 0.55;
    final token = widget.strikeToken ?? 0;
    final plan = slammerScatterPlan(
      token: token,
      power: power,
      vx: vx,
      vy: vy,
    );
    _slammerScatterTarget = plan.offset;
    _slammerScatterFaceUp = plan.faceUp;
    _slammerScatterSpin = plan.spin;
    if (_slammerPhase != SlammerArenaPhase.flyIn) {
      _slammerPhase = SlammerArenaPhase.scatter;
    }

    final dt = sim['dt'] is num ? (sim['dt'] as num).toDouble() : 1.0 / 60.0;
    _simDurationSec = frames.last.stepIndex * dt;
    if (_simDurationSec <= 0) _simDurationSec = dt;
    final wallMs = (_simDurationSec * 1000).round().clamp(1, 15000);
    final settleHold = Duration(
      milliseconds: sim['settleHoldMs'] is num
          ? (sim['settleHoldMs'] as num).round()
          : slamSettleHoldDefault.inMilliseconds,
    );
    final returnMs = sim['returnHomeMs'] is num
        ? (sim['returnHomeMs'] as num).round().clamp(480, 1400)
        : slamReturnHomeDefault.inMilliseconds;

    if (LOGGING_SWITCH) {
      customlog(
        'arcoriStack: sim replay start frames=${frames.length} '
        'simSec=${_simDurationSec.toStringAsFixed(2)} wallMs=$wallMs '
        'settleMs=${settleHold.inMilliseconds} returnMs=$returnMs space=xyzq',
      );
    }

    _scatter.stop();
    _flip.stop();
    _simClock.stop();
    _simClock.value = 0;
    _simClock
        .animateTo(
      1.0,
      duration: Duration(milliseconds: wallMs),
      curve: Curves.linear,
    )
        .whenComplete(() {
      if (!mounted) return;
      _applySimAt(_simDurationSec, dt);
      _applySlammerScatterProgress(1.0);
      _flattenLiveQuatsToRest();
      if (mounted) setState(() {});
      if (LOGGING_SWITCH) {
        customlog(
          'arcoriStack: sim replay complete → settle '
          '${settleHold.inMilliseconds}ms',
        );
      }
      _scheduleReturnHome(settleHold: settleHold, returnMs: returnMs);
    });
  }

  void _applySimAt(double timeSec, double dt) {
    if (_simFrames.isEmpty) return;
    final stepF = timeSec / dt;
    _SimFrame a = _simFrames.first;
    _SimFrame b = _simFrames.last;
    for (var i = 0; i < _simFrames.length - 1; i++) {
      if (stepF >= _simFrames[i].stepIndex &&
          stepF <= _simFrames[i + 1].stepIndex) {
        a = _simFrames[i];
        b = _simFrames[i + 1];
        break;
      }
    }
    final span = (b.stepIndex - a.stepIndex).toDouble();
    final u = span <= 0 ? 1.0 : ((stepF - a.stepIndex) / span).clamp(0.0, 1.0);

    final byIdA = {for (final p in a.poses) p.id: p};
    final byIdB = {for (final p in b.poses) p.id: p};
    for (final id in byIdA.keys) {
      final pa = byIdA[id]!;
      final pb = byIdB[id] ?? pa;
      final x = pa.x + (pb.x - pa.x) * u;
      final y = pa.y + (pb.y - pa.y) * u;
      final z = pa.z + (pb.z - pa.z) * u;
      final q = _nlerp(
        _Quat(pa.qx, pa.qy, pa.qz, pa.qw),
        _Quat(pb.qx, pb.qy, pb.qz, pb.qw),
        u,
      );
      final rest = _restWorld[id] ?? _Vec3(pa.x, pa.y, pa.z);
      // Dead-above: table XZ → screen; full faces read as circles.
      final dx = (x - rest.x) * _pxPerMeter;
      final dyWorld = (y - rest.y) * _pxPerMeter;
      final dz = (z - rest.z) * _pxPerMeter;
      _offsets[id] = Offset(dx, -dz - dyWorld * 0.15);
      _quats[id] = q;
    }
  }

  void _runImpulse(Map<String, dynamic> impulse) {
    final vx = impulse['vx'] is num ? (impulse['vx'] as num).toDouble() : 0.0;
    final vy = impulse['vy'] is num ? (impulse['vy'] as num).toDouble() : 0.0;
    final spin =
        impulse['spin'] is num ? (impulse['spin'] as num).toDouble() : 0.0;
    final power =
        impulse['power'] is num ? (impulse['power'] as num).toDouble() : 0.0;
    _pxPerMeter = kSlamPhysicsPxPerMeter;

    if (LOGGING_SWITCH) {
      customlog(
        'arcoriStack: impulse fallback vx=$vx vy=$vy spin=$spin power=$power',
      );
    }

    final token = widget.strikeToken ?? _impulseNonce;
    final plan = slammerScatterPlan(
      token: token,
      power: power,
      vx: vx,
      vy: vy,
    );
    _slammerScatterTarget = plan.offset;
    _slammerScatterFaceUp = plan.faceUp;
    _slammerScatterSpin = plan.spin;
    _slammerPhase = SlammerArenaPhase.scatter;
    _slammerOffset = _impactOffsetPx();

    const spring = SpringDescription(mass: 1, stiffness: 80, damping: 12);
    final unitVelocity = -(power * 4.0 + spin);
    _scatter.stop();
    _scatter.value = 0;
    unawaited(
      _scatter.animateWith(SpringSimulation(spring, 0, 1, unitVelocity))
          .whenComplete(() {
        if (!mounted) return;
        _applySlammerScatterProgress(1.0);
        _scheduleReturnHome();
      }),
    );

    _flip.stop();
    _flip.value = 0;
    _flip.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 120, damping: 14),
        0,
        1,
        -spin * 2,
      ),
    );

    final sorted = List<MatchPieceView>.from(_pieces)
      ..sort((a, b) => a.stackIndex.compareTo(b.stackIndex));
    for (var i = 0; i < sorted.length; i++) {
      final fromTop = sorted.length - 1 - i;
      final amp = 18.0 + power * 48.0 * (1 + fromTop * 0.35);
      _offsets[sorted[i].pieceId] = Offset(
        vx * amp * (0.6 + fromTop * 0.2),
        -vy * amp * (0.4 + fromTop * 0.15),
      );
    }
  }

  void _scheduleReturnHome({
    Duration settleHold = slamSettleHoldDefault,
    int? returnMs,
  }) {
    final ms = returnMs ?? slamReturnHomeDefault.inMilliseconds;
    _settleHoldTimer?.cancel();
    if (LOGGING_SWITCH) {
      customlog(
        'arcoriStack: settle hold ${settleHold.inMilliseconds}ms '
        'then return ${ms}ms',
      );
    }
    if (settleHold <= Duration.zero) {
      _beginReturnHome(returnMs: ms);
      return;
    }
    _settleHoldTimer = Timer(settleHold, () {
      if (!mounted) return;
      _beginReturnHome(returnMs: ms);
    });
  }

  void _beginReturnHome({required int returnMs}) {
    _settleHoldTimer?.cancel();
    _settleHoldTimer = null;
    // Capture poses while still in sim/impulse paint space.
    _returnFromOffsets.clear();
    _returnFromQuats.clear();
    final sorted = List<MatchPieceView>.from(_pieces)
      ..sort((a, b) => a.stackIndex.compareTo(b.stackIndex));
    const restStackGap = 2.0;
    for (var i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      final o = _offsets[p.pieceId] ?? Offset.zero;
      final base = Offset(0, -i * restStackGap);
      // Sim: absolute world delta. Impulse: base + scatter at t≈1.
      _returnFromOffsets[p.pieceId] = _replayingSim ? o : (base + o);
      _returnFromQuats[p.pieceId] = _quats[p.pieceId] ?? _Quat.faceDown();
      // Switch to absolute paint offsets for the return lerp.
      _offsets[p.pieceId] = _returnFromOffsets[p.pieceId]!;
    }
    _slammerReturnFrom = _slammerOffset;
    _slammerReturnFromQuat = _slammerQuat;

    _replayingSim = false;
    _pieces = List<MatchPieceView>.from(widget.pieces);
    _slammerPhase = SlammerArenaPhase.returnHome;
    _returningHome = true;

    if (LOGGING_SWITCH) {
      customlog('arcoriStack: return home start ms=$returnMs');
    }

    _returnClock.stop();
    _returnClock.value = 0;
    _returnClock
        .animateTo(
      1.0,
      duration: Duration(milliseconds: returnMs),
      curve: Curves.linear,
    )
        .whenComplete(() {
      if (!mounted) return;
      _returningHome = false;
      _snapPiecesToAuthority();
      _slammerPhase = SlammerArenaPhase.atHome;
      _slammerOffset = _homeOffsetPx();
      _slammerQuat = _Quat.faceUp();
      _slammerFaceUp = true;
      if (LOGGING_SWITCH) {
        customlog('arcoriStack: return home complete');
      }
      widget.onSlammerAnimEnded?.call();
      widget.onAnimComplete?.call();
      setState(() {});
    });
  }

  /// Instant authority rest (no motion) — face-down stack.
  void _snapPiecesToAuthority() {
    _syncRest(_pieces);
    for (final p in _pieces) {
      _offsets[p.pieceId] = Offset.zero;
      final cur = _quats[p.pieceId] ??
          (p.faceUp ? _Quat.faceUp() : _Quat.faceDown());
      _quats[p.pieceId] = _restingQuat(cur, p.faceUp);
    }
  }

  bool get _slammerAnimInFlight =>
      !widget.suppressArenaSlammer &&
      widget.strikeLook != null &&
      (_awaitingStrike ||
          _slammerPhase == SlammerArenaPhase.flyIn ||
          _slammerPhase == SlammerArenaPhase.scatter ||
          _slammerPhase == SlammerArenaPhase.returnHome ||
          _settleHoldTimer != null);

  @override
  void dispose() {
    final abortHide = _slammerAnimInFlight;
    _settleHoldTimer?.cancel();
    _scatter.removeListener(_onTick);
    _flip.removeListener(_onTick);
    _simClock.removeListener(_onSimTick);
    _returnClock.removeListener(_onReturnTick);
    _scatter.dispose();
    _flip.dispose();
    _simClock.dispose();
    _returnClock.dispose();
    super.dispose();
    if (abortHide) {
      // Remount mid-anim: restore chrome rest unless a newer claim replaced us.
      widget.onSlammerAnimEnded?.call();
    }
  }

  void _emitPovScale(double fit) {
    final cb = widget.onPovScale;
    if (cb == null) return;
    if (_lastEmittedPovScale != null &&
        (fit - _lastEmittedPovScale!).abs() < 0.002) {
      return;
    }
    _lastEmittedPovScale = fit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onPovScale?.call(fit);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<MatchPieceView>.from(widget.pieces)
      ..sort((a, b) => a.stackIndex.compareTo(b.stackIndex));
    final t = (_replayingSim || _returningHome)
        ? 1.0
        : _scatter.value.clamp(0.0, 1.5);
    // Fit zoom tracks true Arcori spread — ignore spring overshoot past 1.
    final fitT = (_replayingSim || _returningHome) ? 1.0 : t.clamp(0.0, 1.0);
    final ft = (_replayingSim || _returningHome)
        ? 1.0
        : _flip.value.clamp(0.0, 1.5);
    final restDiscSize = kDiscRadius * 2 * kSlamPhysicsPxPerMeter;
    final discSize = restDiscSize;
    // Match chrome rest size so fly-in/return handoff is one continuous disc.
    final slammerSize = MatchPlayerChrome.slammerSize;
    /// Screen gap for stacked discs under dead-above (near-concentric).
    const restStackGap = 2.0;
    /// Dead-above camera — discs settle as full circles.
    const viewPitch = 0.0;
    // Aim marker uses the same px/m as physics so Ø matches rest disc size.
    final aimPpm = kSlamPhysicsPxPerMeter;
    final slammerPx = kDiscRadius * 2 * aimPpm;
    final aimIn =
        !aimOutsideStackFootprint(widget.aimX, widget.aimZ);
    final markerOffset = Offset(widget.aimX * aimPpm, -widget.aimZ * aimPpm);

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _arenaSize = Size(constraints.maxWidth, constraints.maxHeight);
          // POV fit = Arcori paint spread only (not aim, not slammer).
          var maxAbsX = restDiscSize * 0.5;
          var maxAbsY = restDiscSize * 0.5;
          for (var i = 0; i < sorted.length; i++) {
            final p = sorted[i];
            final raw = _offsets[p.pieceId] ?? Offset.zero;
            final Offset paintOffset;
            if (_returningHome) {
              paintOffset = raw;
            } else if (_replayingSim) {
              paintOffset = raw;
            } else {
              paintOffset = Offset(0, -i * restStackGap) + raw * fitT;
            }
            maxAbsX =
                max(maxAbsX, paintOffset.dx.abs() + restDiscSize * 0.5);
            maxAbsY =
                max(maxAbsY, paintOffset.dy.abs() + restDiscSize * 0.5);
          }
          const pad = 10.0;
          final halfW = max(1.0, constraints.maxWidth * 0.5 - pad);
          final halfH = max(1.0, constraints.maxHeight * 0.5 - pad);
          // Tiny/zero layout slots would clamp to the contain floor — skip.
          final layoutOk =
              constraints.maxWidth >= 48 && constraints.maxHeight >= 48;
          final fit = layoutOk
              ? min(halfW / maxAbsX, halfH / maxAbsY)
                  .clamp(kStackPovFitMin, 1.0)
              : (_lastEmittedPovScale ?? 1.0);
          if (layoutOk) {
            _emitPovScale(fit);
          }
          final hud = context.appHud;
          final padFill = hud.onGlass.withValues(alpha: 0.10);
          final padEdge = AppColors.onSurface.withValues(alpha: 0.28);
          final padBorder = hud.onGlassMuted.withValues(alpha: 0.35);
          final aimColor = aimIn ? hud.aimLocked : hud.missZone;

          Widget table = Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Dead-above table pad (round, under stack).
                  Center(
                    child: Container(
                      width: discSize * 2.4,
                      height: discSize * 2.4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            padFill,
                            padEdge,
                          ],
                        ),
                        border: Border.all(color: padBorder),
                      ),
                    ),
                  ),
                  for (var i = 0; i < sorted.length; i++)
                    Builder(
                      builder: (context) {
                        final p = sorted[i];
                        final base = (_replayingSim || _returningHome)
                            ? Offset.zero
                            : Offset(0, -i * restStackGap);
                        final scatter =
                            (_offsets[p.pieceId] ?? Offset.zero) * t;
                        final paintOffset = _returningHome
                            ? (_offsets[p.pieceId] ?? Offset.zero)
                            : (base + scatter);
                        late final _Quat q;
                        if (_replayingSim || _returningHome) {
                          q = _quats[p.pieceId] ?? _Quat.faceDown();
                        } else {
                          final start =
                              _quats[p.pieceId] ?? _Quat.faceDown();
                          final target = _restingQuat(start, p.faceUp);
                          q = _nlerp(start, target, ft.clamp(0.0, 1.0));
                          final wobble = (1 - ft.clamp(0.0, 1.0)) *
                              sin(ft * pi) *
                              ((_impulseNonce > 0) ? 0.25 : 0);
                          if (wobble != 0) {
                            final wob = Quaternion.axisAngle(
                              Vector3(1, 0.2, 0.4),
                              wobble,
                            );
                            final cur = Quaternion(q.x, q.y, q.z, q.w);
                            final mixed = (wob * cur)..normalize();
                            return ArcoriDisc(
                              piece: p,
                              size: discSize,
                              offset: paintOffset,
                              viewPitch: viewPitch,
                              qx: mixed.x,
                              qy: mixed.y,
                              qz: mixed.z,
                              qw: mixed.w,
                              faceUpOverride: p.faceUp,
                            );
                          }
                        }
                        return ArcoriDisc(
                          piece: p,
                          size: discSize,
                          offset: paintOffset,
                          viewPitch: viewPitch,
                          qx: q.x,
                          qy: q.y,
                          qz: q.z,
                          qw: q.w,
                          faceUpOverride: (_replayingSim || _returningHome)
                              ? null
                              : p.faceUp,
                        );
                      },
                    ),
                  if (widget.showAimMarker)
                    Transform.translate(
                      offset: markerOffset,
                      child: Container(
                        width: slammerPx,
                        height: slammerPx,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: aimColor,
                            width: 2.5,
                          ),
                          color: aimColor.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  if (sorted.isEmpty)
                    const Text(
                      'No Arcori on table',
                      textAlign: TextAlign.center,
                    ),
                  if (_showSlammer)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: SlammerArenaDisc(
                          key: ValueKey('slammer-${widget.strikeToken}'),
                          look: widget.strikeLook!,
                          lottieUrl: widget.strikeLottieUrl,
                          home: _homeOffsetPx(),
                          token: widget.strikeToken!,
                          phase: _awaitingStrike
                              ? SlammerArenaPhase.flyIn
                              : _slammerPhase,
                          aimX: widget.aimX,
                          aimZ: widget.aimZ,
                          offset: _slammerOffset,
                          qx: _slammerQuat.x,
                          qy: _slammerQuat.y,
                          qz: _slammerQuat.z,
                          qw: _slammerQuat.w,
                          size: slammerSize,
                          faceUpOverride: _slammerPhase ==
                                      SlammerArenaPhase.scatter ||
                                  _slammerPhase == SlammerArenaPhase.returnHome
                              ? _slammerFaceUp
                              : true,
                          onFlyInComplete:
                              _awaitingStrike ? _onStrikeComplete : null,
                        ),
                      ),
                    ),
                ],
          );

          if ((widget.worldScale - 1.0).abs() > 1e-6) {
            table = Transform.scale(
              scale: widget.worldScale,
              alignment: Alignment.center,
              child: table,
            );
          }
          if (widget.applyFitZoom) {
            table = ClipRect(
              child: Transform.scale(
                scale: fit,
                alignment: Alignment.center,
                child: table,
              ),
            );
          }
          return table;
        },
      ),
    );
  }
}

class _Quat {
  const _Quat(this.x, this.y, this.z, this.w);

  factory _Quat.faceUp() => const _Quat(0, 0, 0, 1);

  factory _Quat.faceDown() {
    final q = Quaternion.axisAngle(Vector3(1, 0, 0), pi);
    return _Quat(q.x, q.y, q.z, q.w);
  }

  final double x;
  final double y;
  final double z;
  final double w;
}

class _Vec3 {
  const _Vec3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

class _SimPose {
  const _SimPose({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.qx,
    required this.qy,
    required this.qz,
    required this.qw,
  });

  final String id;
  final double x;
  final double y;
  final double z;
  final double qx;
  final double qy;
  final double qz;
  final double qw;
}

class _SimFrame {
  const _SimFrame({required this.stepIndex, required this.poses});

  final int stepIndex;
  final List<_SimPose> poses;
}

_Quat _restingQuat(_Quat q, bool faceUp) {
  final rest = restingOrientationFrom(
    vm.Quaternion(q.x, q.y, q.z, q.w)..normalize(),
    faceUp: faceUp,
  );
  return _Quat(rest.x, rest.y, rest.z, rest.w);
}

_Quat _nlerp(_Quat a, _Quat b, double t) {
  var bx = b.x;
  var by = b.y;
  var bz = b.z;
  var bw = b.w;
  // Same hemisphere.
  if (a.x * bx + a.y * by + a.z * bz + a.w * bw < 0) {
    bx = -bx;
    by = -by;
    bz = -bz;
    bw = -bw;
  }
  final x = a.x + (bx - a.x) * t;
  final y = a.y + (by - a.y) * t;
  final z = a.z + (bz - a.z) * t;
  final w = a.w + (bw - a.w) * t;
  final n = sqrt(x * x + y * y + z * z + w * w);
  if (n < 1e-9) return a;
  return _Quat(x / n, y / n, z / n, w / n);
}

List<_SimFrame> _parseSimFrames(Map<String, dynamic>? sim) {
  if (sim == null) return const [];
  // Ignore legacy 2D side-view frames (no space / not xyzq).
  final space = sim['space']?.toString();
  if (space != null && space != 'xyzq') return const [];
  final raw = sim['frames'];
  if (raw is! List) return const [];
  final out = <_SimFrame>[];
  for (final f in raw) {
    if (f is! Map) continue;
    final map = Map<String, dynamic>.from(f);
    final i = map['i'] is int
        ? map['i'] as int
        : (map['i'] is num ? (map['i'] as num).toInt() : 0);
    final posesRaw = map['p'];
    if (posesRaw is! List) continue;
    final poses = <_SimPose>[];
    for (final row in posesRaw) {
      if (row is! List || row.length < 8) continue;
      poses.add(
        _SimPose(
          id: row[0].toString(),
          x: row[1] is num ? (row[1] as num).toDouble() : 0,
          y: row[2] is num ? (row[2] as num).toDouble() : 0,
          z: row[3] is num ? (row[3] as num).toDouble() : 0,
          qx: row[4] is num ? (row[4] as num).toDouble() : 0,
          qy: row[5] is num ? (row[5] as num).toDouble() : 0,
          qz: row[6] is num ? (row[6] as num).toDouble() : 0,
          qw: row[7] is num ? (row[7] as num).toDouble() : 1,
        ),
      );
    }
    if (poses.isNotEmpty) {
      out.add(_SimFrame(stepIndex: i, poses: poses));
    }
  }
  // If frames exist but none were xyzq-shaped and space omitted, reject 2D.
  if (out.isEmpty && raw.isNotEmpty && space == null) {
    return const [];
  }
  return out;
}

bool _impulsesEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  return a['vx'] == b['vx'] &&
      a['vy'] == b['vy'] &&
      a['spin'] == b['spin'] &&
      a['power'] == b['power'];
}
