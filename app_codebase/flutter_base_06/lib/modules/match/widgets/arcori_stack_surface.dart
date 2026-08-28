import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../utils/dev_logger.dart';
import '../state/match_snapshot_state.dart';
import 'arcori_disc.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Face-down Arcori stack with spring scatter / flip from slam impulse.
class ArcoriStackSurface extends StatefulWidget {
  const ArcoriStackSurface({
    super.key,
    required this.pieces,
    this.impulse,
    this.height = 160,
  });

  final List<MatchPieceView> pieces;
  final Map<String, dynamic>? impulse;
  final double height;

  @override
  State<ArcoriStackSurface> createState() => _ArcoriStackSurfaceState();
}

class _ArcoriStackSurfaceState extends State<ArcoriStackSurface>
    with TickerProviderStateMixin {
  late final AnimationController _scatter;
  late final AnimationController _flip;

  final Map<String, Offset> _offsets = {};
  final Map<String, double> _rots = {};
  List<MatchPieceView> _pieces = const [];
  int _impulseNonce = 0;

  @override
  void initState() {
    super.initState();
    _scatter = AnimationController.unbounded(vsync: this);
    _flip = AnimationController.unbounded(vsync: this);
    _pieces = List<MatchPieceView>.from(widget.pieces);
    _syncRest(_pieces);
    _scatter.addListener(_onTick);
    _flip.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant ArcoriStackSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final piecesChanged = !_samePieces(oldWidget.pieces, widget.pieces);
    if (piecesChanged) {
      _pieces = List<MatchPieceView>.from(widget.pieces);
      _settleToAuthority();
    }
    if (!_impulsesEqual(widget.impulse, oldWidget.impulse) &&
        widget.impulse != null) {
      _impulseNonce++;
      _runImpulse(widget.impulse!);
    }
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

  void _runImpulse(Map<String, dynamic> impulse) {
    final vx = impulse['vx'] is num ? (impulse['vx'] as num).toDouble() : 0.0;
    final vy = impulse['vy'] is num ? (impulse['vy'] as num).toDouble() : 0.0;
    final spin =
        impulse['spin'] is num ? (impulse['spin'] as num).toDouble() : 0.0;
    final power =
        impulse['power'] is num ? (impulse['power'] as num).toDouble() : 0.0;

    if (LOGGING_SWITCH) {
      customlog(
        'arcoriStack: impulse vx=$vx vy=$vy spin=$spin power=$power',
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
    _scatter.dispose();
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<MatchPieceView>.from(widget.pieces)
      ..sort((a, b) => a.stackIndex.compareTo(b.stackIndex));
    final t = _scatter.value.clamp(0.0, 1.5);
    final ft = _flip.value.clamp(0.0, 1.5);
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
                final targetRot = p.faceUp ? pi : 0.0;
                final startRot = _rots[p.pieceId] ?? 0.0;
                final rot = startRot +
                    (targetRot - startRot) * ft.clamp(0.0, 1.0) +
                    (1 - ft.clamp(0.0, 1.0)) *
                        sin(ft * pi) *
                        ((_impulseNonce > 0) ? 0.4 : 0);
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

bool _impulsesEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  return a['vx'] == b['vx'] &&
      a['vy'] == b['vy'] &&
      a['spin'] == b['spin'] &&
      a['power'] == b['power'];
}
