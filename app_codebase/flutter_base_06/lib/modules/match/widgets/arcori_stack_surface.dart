import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../utils/dev_logger.dart';
import '../state/match_snapshot_state.dart';
import 'arcori_disc.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Cap wall-clock replay so long sims stay snappy in UX.
const Duration kSimReplayMaxWall = Duration(milliseconds: 2500);

/// Face-down Arcori stack — replays Forge2D pose timeline, or spring fallback.
class ArcoriStackSurface extends StatefulWidget {
  const ArcoriStackSurface({
    super.key,
    required this.pieces,
    this.impulse,
    this.sim,
    this.height = 160,
  });

  final List<MatchPieceView> pieces;
  final Map<String, dynamic>? impulse;
  final Map<String, dynamic>? sim;
  final double height;

  @override
  State<ArcoriStackSurface> createState() => _ArcoriStackSurfaceState();
}

class _ArcoriStackSurfaceState extends State<ArcoriStackSurface>
    with TickerProviderStateMixin {
  late final AnimationController _scatter;
  late final AnimationController _flip;
  late final AnimationController _simClock;

  final Map<String, Offset> _offsets = {};
  final Map<String, double> _rots = {};
  List<MatchPieceView> _pieces = const [];
  int _impulseNonce = 0;
  bool _replayingSim = false;
  List<_SimFrame> _simFrames = const [];
  double _pxPerMeter = 80;
  double _simDurationSec = 1.0;
  final Map<String, Offset> _restWorld = {};

  bool get _simReady {
    final frames = _parseSimFrames(widget.sim);
    return frames.length >= 2;
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

    final simChanged = !_simsEqual(widget.sim, oldWidget.sim);
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
      _rots[p.pieceId] ??= p.faceUp ? pi : 0.0;
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
    _replayingSim = true;
    _simFrames = frames;
    _pxPerMeter = sim['pxPerMeter'] is num
        ? (sim['pxPerMeter'] as num).toDouble()
        : 80.0;
    _restWorld.clear();
    for (final pose in frames.first.poses) {
      _restWorld[pose.id] = Offset(pose.x, pose.y);
      _rots[pose.id] = pose.angle;
      _offsets[pose.id] = Offset.zero;
    }

    final dt = sim['dt'] is num ? (sim['dt'] as num).toDouble() : 1.0 / 60.0;
    _simDurationSec = frames.last.stepIndex * dt;
    if (_simDurationSec <= 0) _simDurationSec = dt;
    final wallMs = (_simDurationSec * 1000)
        .round()
        .clamp(1, kSimReplayMaxWall.inMilliseconds);

    if (LOGGING_SWITCH) {
      customlog(
        'arcoriStack: sim replay start frames=${frames.length} '
        'simSec=${_simDurationSec.toStringAsFixed(2)} wallMs=$wallMs',
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
      if (LOGGING_SWITCH) {
        customlog('arcoriStack: sim replay complete → settle authority');
      }
      _replayingSim = false;
      _pieces = List<MatchPieceView>.from(widget.pieces);
      _settleToAuthority();
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
      final ang = pa.angle + (pb.angle - pa.angle) * u;
      final rest = _restWorld[id] ?? Offset(pa.x, pa.y);
      _offsets[id] = Offset(
        (x - rest.dx) * _pxPerMeter,
        -(y - rest.dy) * _pxPerMeter,
      );
      _rots[id] = ang;
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
    _scatter.animateWith(SpringSimulation(spring, 0, 1, unitVelocity));

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
      _rots[p.pieceId] = p.faceUp ? pi : 0.0;
    }
  }

  @override
  void dispose() {
    _scatter.removeListener(_onTick);
    _flip.removeListener(_onTick);
    _simClock.removeListener(_onSimTick);
    _scatter.dispose();
    _flip.dispose();
    _simClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<MatchPieceView>.from(widget.pieces)
      ..sort((a, b) => a.stackIndex.compareTo(b.stackIndex));
    final t = _replayingSim ? 1.0 : _scatter.value.clamp(0.0, 1.5);
    final ft = _replayingSim ? 1.0 : _flip.value.clamp(0.0, 1.5);
    const discSize = 72.0;

    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < sorted.length; i++)
            Builder(
              builder: (context) {
                final p = sorted[i];
                final base = Offset(0, -i * 3.0);
                final scatter = (_offsets[p.pieceId] ?? Offset.zero) * t;
                final double rot;
                if (_replayingSim) {
                  rot = _rots[p.pieceId] ?? 0.0;
                } else {
                  final targetRot = p.faceUp ? pi : 0.0;
                  final startRot = _rots[p.pieceId] ?? 0.0;
                  rot = startRot +
                      (targetRot - startRot) * ft.clamp(0.0, 1.0) +
                      (1 - ft.clamp(0.0, 1.0)) *
                          sin(ft * pi) *
                          ((_impulseNonce > 0) ? 0.4 : 0);
                }
                return ArcoriDisc(
                  piece: p,
                  size: discSize,
                  offset: base + scatter,
                  rotationX: rot,
                );
              },
            ),
          if (sorted.isEmpty)
            const Text('No Arcori on table', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SimPose {
  const _SimPose({
    required this.id,
    required this.x,
    required this.y,
    required this.angle,
  });

  final String id;
  final double x;
  final double y;
  final double angle;
}

class _SimFrame {
  const _SimFrame({required this.stepIndex, required this.poses});

  final int stepIndex;
  final List<_SimPose> poses;
}

List<_SimFrame> _parseSimFrames(Map<String, dynamic>? sim) {
  if (sim == null) return const [];
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
      if (row is! List || row.length < 4) continue;
      poses.add(
        _SimPose(
          id: row[0].toString(),
          x: row[1] is num ? (row[1] as num).toDouble() : 0,
          y: row[2] is num ? (row[2] as num).toDouble() : 0,
          angle: row[3] is num ? (row[3] as num).toDouble() : 0,
        ),
      );
    }
    if (poses.isNotEmpty) {
      out.add(_SimFrame(stepIndex: i, poses: poses));
    }
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

bool _simsEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  final fa = a['frames'];
  final fb = b['frames'];
  if (fa is! List || fb is! List) return fa == fb;
  if (fa.length != fb.length) return false;
  if (fa.isEmpty) return true;
  return fa.first.toString() == fb.first.toString() &&
      fa.last.toString() == fb.last.toString();
}
