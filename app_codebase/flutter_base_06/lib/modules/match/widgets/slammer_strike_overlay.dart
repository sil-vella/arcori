import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../../kin/widgets/kin_lottie_preview.dart';
import '../input/turn_pacing.dart';
import 'arcori_cylinder.dart';
import 'arcori_disc.dart' show faceUpFromQuat, matrixFromQuat;
import 'arcori_look.dart';

/// Equipped slammer is slightly larger than an Arcori disc on the table.
const double kSlammerToArcoriScale = 1.22;

/// Arena phases for the equipped slammer after a slam.
enum SlammerArenaPhase {
  /// Flying from player seat toward the stack.
  flyIn,

  /// Tumbling with the Arcori scatter (face up or down).
  scatter,

  /// Sliding back to the acting player's seat.
  returnHome,

  /// Resting at the player seat.
  atHome,
}

/// Equipped slammer on the match arena (fly-in → scatter → return home).
///
/// Parent drives [phase], [offset], and quat during scatter/return. Fly-in is
/// local; [onFlyInComplete] fires once when the strike reaches the stack.
///
/// [home] is a pixel offset from stack center (beside the acting avatar).
class SlammerArenaDisc extends StatefulWidget {
  const SlammerArenaDisc({
    super.key,
    required this.look,
    required this.home,
    required this.token,
    required this.phase,
    this.lottieUrl,
    this.aimX = 0,
    this.aimZ = 0,
    this.offset = Offset.zero,
    this.qx = 0,
    this.qy = 0,
    this.qz = 0,
    this.qw = 1,
    this.faceUpOverride,
    this.flyInDuration = slamStrikeHoldDefault,
    this.size = 56,
    this.onFlyInComplete,
  });

  final ArcoriLook look;
  final String? lottieUrl;

  /// Pixel offset from stack center — beside avatar, toward the board.
  final Offset home;
  final int token;
  final SlammerArenaPhase phase;
  final double aimX;
  final double aimZ;

  /// Scatter / return paint offset from stack center (px).
  final Offset offset;
  final double qx;
  final double qy;
  final double qz;
  final double qw;
  final bool? faceUpOverride;
  final Duration flyInDuration;
  final double size;
  final VoidCallback? onFlyInComplete;

  @override
  State<SlammerArenaDisc> createState() => _SlammerArenaDiscState();
}

class _SlammerArenaDiscState extends State<SlammerArenaDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flyIn;
  late Animation<double> _flyT;
  int? _playedToken;
  bool _flyNotified = false;

  Offset _impactOffset(Size arena) {
    final impactX = (widget.aimX * 0.35).clamp(-0.35, 0.35);
    final impactY = (widget.aimZ * 0.35).clamp(-0.35, 0.35);
    return Offset(impactX * arena.width * 0.5, impactY * arena.height * 0.5);
  }

  /// In-plane yaw so the face reads toward the stack (board center).
  double _boardFacingYaw(Offset home) {
    if (home.distance < 1e-3) return 0;
    return atan2(-home.dx, -home.dy);
  }

  @override
  void initState() {
    super.initState();
    _flyIn = AnimationController(vsync: this, duration: widget.flyInDuration);
    _flyT = CurvedAnimation(parent: _flyIn, curve: Curves.easeInCubic);
    _flyIn.addStatusListener(_onFlyStatus);
    _syncFlyIn(force: true);
  }

  @override
  void didUpdateWidget(covariant SlammerArenaDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token ||
        oldWidget.flyInDuration != widget.flyInDuration ||
        oldWidget.phase != widget.phase) {
      _flyIn.duration = widget.flyInDuration;
      _syncFlyIn(force: oldWidget.token != widget.token);
    }
  }

  void _onFlyStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_flyNotified) return;
    _flyNotified = true;
    widget.onFlyInComplete?.call();
  }

  void _syncFlyIn({required bool force}) {
    if (widget.phase != SlammerArenaPhase.flyIn) {
      _flyIn.stop();
      _flyIn.value = 1;
      return;
    }
    if (!force && _playedToken == widget.token) return;
    _playedToken = widget.token;
    _flyNotified = false;
    _flyIn.stop();
    _flyIn.value = 0;
    _flyIn.forward();
  }

  @override
  void dispose() {
    _flyIn.removeStatusListener(_onFlyStatus);
    _flyIn.dispose();
    super.dispose();
  }

  Widget _cylinder({required bool faceUp}) {
    final useLottie = (widget.lottieUrl ?? '').trim().isNotEmpty;
    return ArcoriCylinder(
      look: ArcoriLook(
        designId: widget.look.designId,
        imageUrl: useLottie ? null : widget.look.imageUrl,
        colorHex: widget.look.colorHex,
      ),
      size: widget.size,
      faceUp: faceUp,
      showThickness: true,
      face: useLottie
          ? KinSceneStack(
              lottieUrl: widget.lottieUrl,
              fit: BoxFit.cover,
            )
          : null,
    );
  }

  Widget _atHomeDisc() {
    final yaw = _boardFacingYaw(widget.home);
    return Transform.translate(
      offset: widget.home,
      child: Transform.rotate(
        angle: yaw,
        child: _cylinder(faceUp: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.phase) {
      case SlammerArenaPhase.flyIn:
        return LayoutBuilder(
          builder: (context, constraints) {
            final arena = Size(constraints.maxWidth, constraints.maxHeight);
            final impact = _impactOffset(arena);
            return AnimatedBuilder(
              animation: _flyT,
              builder: (context, child) {
                final u = _flyT.value;
                final fly = (u / 0.88).clamp(0.0, 1.0);
                final squash =
                    u > 0.88 ? ((u - 0.88) / 0.12).clamp(0.0, 1.0) : 0.0;
                final pos = Offset.lerp(widget.home, impact, fly)!;
                final scale = 1.0 + 0.12 * (1.0 - fly) - 0.08 * squash;
                return Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: pos,
                    child: Transform.scale(scale: scale, child: child),
                  ),
                );
              },
              child: _cylinder(faceUp: true),
            );
          },
        );

      case SlammerArenaPhase.scatter:
      case SlammerArenaPhase.returnHome:
        final faceUp = widget.faceUpOverride ??
            faceUpFromQuat(widget.qx, widget.qy, widget.qz, widget.qw);
        final transform = Matrix4.identity()
          ..translate(widget.offset.dx, widget.offset.dy);
        transform.multiply(
          matrixFromQuat(widget.qx, widget.qy, widget.qz, widget.qw),
        );
        return Align(
          alignment: Alignment.center,
          child: Transform(
            alignment: Alignment.center,
            transform: transform,
            child: _cylinder(faceUp: faceUp),
          ),
        );

      case SlammerArenaPhase.atHome:
        return Align(
          alignment: Alignment.center,
          child: _atHomeDisc(),
        );
    }
  }
}

/// Deterministic scatter target for a slam token (px from stack center).
({Offset offset, bool faceUp, double spin}) slammerScatterPlan({
  required int token,
  required double power,
  required double vx,
  required double vy,
}) {
  final rng = Random(token & 0x7fffffff);
  final amp = 28.0 + power.clamp(0.0, 1.0) * 72.0;
  final ox = (vx * amp * (0.7 + rng.nextDouble() * 0.5)) +
      (rng.nextDouble() - 0.5) * 36;
  final oy = (-vy * amp * (0.55 + rng.nextDouble() * 0.45)) +
      (rng.nextDouble() - 0.5) * 36;
  return (
    offset: Offset(ox, oy),
    faceUp: rng.nextBool(),
    spin: (rng.nextDouble() - 0.5) * pi * 2.4,
  );
}

/// Build a resting face-up / face-down quat with optional in-plane spin.
Quaternion slammerRestQuat({required bool faceUp, double yaw = 0}) {
  final yawQ = Quaternion.axisAngle(Vector3(0, 1, 0), yaw)..normalize();
  if (faceUp) return yawQ;
  final down = yawQ * Quaternion.axisAngle(Vector3(1, 0, 0), pi);
  down.normalize();
  return down;
}
