import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../../../utils/dev_logger.dart';
import '../state/match_snapshot_state.dart';
import '../input/slam_input_models.dart';
import '../input/slam_physics_world.dart';
import '../input/turn_pacing.dart';
import 'arcori_disc.dart' show ArcoriDisc, faceUpFromQuat;
import 'arena_pov_backdrop.dart';

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

  @override
  State<ArcoriStackSurface> createState() => _ArcoriStackSurfaceState();
}

class _ArcoriStackSurfaceState extends State<ArcoriStackSurface>
    with TickerProviderStateMixin {
  late final AnimationController _scatter;
  late final AnimationController _flip;
  late final AnimationController _simClock;

  final Map<String, Offset> _offsets = {};
  final Map<String, _Quat> _quats = {};
  List<MatchPieceView> _pieces = const [];
  int _impulseNonce = 0;
  bool _replayingSim = false;
  List<_SimFrame> _simFrames = const [];
  double _pxPerMeter = 80;
  double _simDurationSec = 1.0;
  double? _lastEmittedPovScale;
  final Map<String, _Vec3> _restWorld = {};
  Timer? _settleHoldTimer;
  /// Fingerprint of the sim currently playing / last finished — skip restarts.
  String? _simFingerprint;

  bool get _simReady {
    final frames = _parseSimFrames(widget.sim);
    return frames.length >= 2;
  }

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
    _pieces = List<MatchPieceView>.from(widget.pieces);
    _syncRest(_pieces);
    _scatter.addListener(_onTick);
    _flip.addListener(_onTick);
    _simClock.addListener(_onSimTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_simReady) {
        _startSimIfPossible(force: true);
      } else if (widget.impulse != null) {
        _impulseNonce++;
        _runImpulse(widget.impulse!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ArcoriStackSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final piecesChanged = !_samePieces(oldWidget.pieces, widget.pieces);
    if (piecesChanged) {
      _pieces = List<MatchPieceView>.from(widget.pieces);
      if (!_replayingSim) {
        _settleToAuthority();
      }
    }

    final nextFp = _fingerprintSim(widget.sim);
    final simChanged = nextFp != null && nextFp != _simFingerprint;
    if (simChanged && _simReady) {
      _impulseNonce++;
      _startSimIfPossible(force: true);
      return;
    }

    if (!_simReady &&
        !_impulsesEqual(widget.impulse, oldWidget.impulse) &&
        widget.impulse != null &&
        !_replayingSim) {
      _impulseNonce++;
      _runImpulse(widget.impulse!);
    }
  }

  void _startSimIfPossible({required bool force}) {
    final frames = _parseSimFrames(widget.sim);
    if (frames.length < 2) return;
    final fp = _fingerprintSim(widget.sim);
    // Same sim already played or playing — never restart (parent remount /
    // clearTurnAnimLock rebuilds used to loop the last slam).
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
    if (mounted) setState(() {});
  }

  void _onSimTick() {
    if (!_replayingSim || _simFrames.isEmpty) return;
    final dt = widget.sim?['dt'] is num
        ? (widget.sim!['dt'] as num).toDouble()
        : 1.0 / 60.0;
    final time = _simClock.value * _simDurationSec;
    _applySimAt(time, dt);
    if (mounted) setState(() {});
  }

  void _runSim(Map<String, dynamic> sim, List<_SimFrame> frames) {
    _settleHoldTimer?.cancel();
    _settleHoldTimer = null;
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

    final dt = sim['dt'] is num ? (sim['dt'] as num).toDouble() : 1.0 / 60.0;
    _simDurationSec = frames.last.stepIndex * dt;
    if (_simDurationSec <= 0) _simDurationSec = dt;
    // 1:1 with physics steps (backend animHoldMs covers replay + settle + pad).
    final wallMs = (_simDurationSec * 1000).round().clamp(1, 15000);
    final settleHold = Duration(
      milliseconds: sim['settleHoldMs'] is num
          ? (sim['settleHoldMs'] as num).round()
          : slamSettleHoldDefault.inMilliseconds,
    );

    if (LOGGING_SWITCH) {
      customlog(
        'arcoriStack: sim replay start frames=${frames.length} '
        'simSec=${_simDurationSec.toStringAsFixed(2)} wallMs=$wallMs '
        'settleHoldMs=${settleHold.inMilliseconds} space=xyzq',
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
      // Freeze on last poses, then hold before stack snap.
      _applySimAt(_simDurationSec, dt);
      _flattenLiveQuatsToRest();
      if (mounted) setState(() {});
      if (LOGGING_SWITCH) {
        customlog(
          'arcoriStack: sim replay complete → hold '
          '${settleHold.inMilliseconds}ms before settle',
        );
      }
      _settleHoldTimer?.cancel();
      _settleHoldTimer = Timer(settleHold, () {
        if (!mounted) return;
        if (LOGGING_SWITCH) {
          customlog(
            'arcoriStack: settle authority after hold '
            'tableFaceUp=${widget.pieces.map((p) => '${p.pieceId}:${p.faceUp}').join(',')}',
          );
        }
        _replayingSim = false;
        _pieces = List<MatchPieceView>.from(widget.pieces);
        _settleToAuthority();
        widget.onAnimComplete?.call();
        setState(() {});
      });
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

    if (LOGGING_SWITCH) {
      customlog(
        'arcoriStack: impulse fallback vx=$vx vy=$vy spin=$spin power=$power',
      );
    }

    const spring = SpringDescription(mass: 1, stiffness: 80, damping: 12);
    final unitVelocity = -(power * 4.0 + spin);
    _scatter.stop();
    _scatter.value = 0;
    unawaited(
      _scatter.animateWith(SpringSimulation(spring, 0, 1, unitVelocity))
          .whenComplete(() {
        if (!mounted) return;
        widget.onAnimComplete?.call();
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

  void _settleToAuthority() {
    _syncRest(_pieces);
    const spring = SpringDescription(mass: 1, stiffness: 100, damping: 16);
    _scatter.stop();
    _scatter.value = 0;
    _scatter.animateWith(SpringSimulation(spring, 0, 1, 0));
    _flip.stop();
    _flip.value = 0;
    _flip.animateWith(SpringSimulation(spring, 0, 1, 0));

    for (final p in _pieces) {
      _offsets[p.pieceId] = Offset.zero;
      final cur = _quats[p.pieceId] ??
          (p.faceUp ? _Quat.faceUp() : _Quat.faceDown());
      // Table after restack is all face-down — do not keep slam-result faces.
      _quats[p.pieceId] = _restingQuat(cur, p.faceUp);
    }
  }

  @override
  void dispose() {
    _settleHoldTimer?.cancel();
    _scatter.removeListener(_onTick);
    _flip.removeListener(_onTick);
    _simClock.removeListener(_onSimTick);
    _scatter.dispose();
    _flip.dispose();
    _simClock.dispose();
    super.dispose();
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
    final t = _replayingSim ? 1.0 : _scatter.value.clamp(0.0, 1.5);
    final ft = _replayingSim ? 1.0 : _flip.value.clamp(0.0, 1.5);
    final restDiscSize = kDiscRadius * 2 * kSlamPhysicsPxPerMeter;
    final discSize = restDiscSize;
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
          // Fit zoom: keep every disc (+ aim marker) inside the viewport.
          // Use rest (unscaled) sizes so shared arena camera still pulls back
          // when pieces would leave the table slot.
          var maxAbsX = restDiscSize * 0.5;
          var maxAbsY = restDiscSize * 0.5;
          for (var i = 0; i < sorted.length; i++) {
            final p = sorted[i];
            final base =
                _replayingSim ? Offset.zero : Offset(0, -i * restStackGap);
            final scatter = (_offsets[p.pieceId] ?? Offset.zero) * t;
            final o = base + scatter;
            maxAbsX = max(maxAbsX, o.dx.abs() + restDiscSize * 0.5);
            maxAbsY = max(maxAbsY, o.dy.abs() + restDiscSize * 0.5);
          }
          if (widget.showAimMarker) {
            final restAim = kDiscRadius * 2 * kSlamPhysicsPxPerMeter;
            final restMarker = Offset(
              widget.aimX * kSlamPhysicsPxPerMeter,
              -widget.aimZ * kSlamPhysicsPxPerMeter,
            );
            maxAbsX = max(maxAbsX, restMarker.dx.abs() + restAim * 0.5);
            maxAbsY = max(maxAbsY, restMarker.dy.abs() + restAim * 0.5);
          }
          const pad = 10.0;
          final halfW = max(1.0, constraints.maxWidth * 0.5 - pad);
          final halfH = max(1.0, constraints.maxHeight * 0.5 - pad);
          final fit =
              min(halfW / maxAbsX, halfH / maxAbsY).clamp(kStackPovFitMin, 1.0);
          _emitPovScale(fit);

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
                            Colors.white.withValues(alpha: 0.10),
                            Colors.black.withValues(alpha: 0.28),
                          ],
                        ),
                        border: Border.all(color: Colors.white12),
                      ),
                    ),
                  ),
                  for (var i = 0; i < sorted.length; i++)
                    Builder(
                      builder: (context) {
                        final p = sorted[i];
                        final base = _replayingSim
                            ? Offset.zero
                            : Offset(0, -i * restStackGap);
                        final scatter =
                            (_offsets[p.pieceId] ?? Offset.zero) * t;
                        final paintOffset = base + scatter;
                        late final _Quat q;
                        if (_replayingSim) {
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
                          faceUpOverride:
                              _replayingSim ? null : p.faceUp,
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
                            color: aimIn
                                ? Colors.lightGreenAccent
                                : Colors.redAccent,
                            width: 2.5,
                          ),
                          color: (aimIn
                                  ? Colors.lightGreenAccent
                                  : Colors.redAccent)
                              .withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  if (sorted.isEmpty)
                    const Text(
                      'No Arcori on table',
                      textAlign: TextAlign.center,
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
