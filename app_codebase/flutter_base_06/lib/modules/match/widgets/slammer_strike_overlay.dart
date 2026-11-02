import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../../audio/audio_catalog.dart';
import '../../audio/audio_playback.dart';
import '../../kin/widgets/kin_lottie_preview.dart';
import '../input/turn_pacing.dart';
import 'arcori_cylinder.dart';
import 'arcori_disc.dart' show faceUpFromQuat, matrixFromQuat;
import 'arcori_look.dart';
import 'hand_under_slammer.dart';
import 'slam_strike_motion.dart';

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
class SlammerArenaDisc extends ConsumerStatefulWidget {
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
    this.handImageUrl,
    this.handAspect = 768 / 512,
    this.handDock = SlammerDockSide.top,
    this.onFlyInComplete,
    this.onLocalHitFeedback,
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

  /// Owned hand art. It follows the strike scale, then returns home.
  final String? handImageUrl;
  final double handAspect;
  final SlammerDockSide handDock;
  final VoidCallback? onFlyInComplete;

  /// Local player only — vibrate/shake. Fired even when [onFlyInComplete] is null.
  final VoidCallback? onLocalHitFeedback;

  @override
  ConsumerState<SlammerArenaDisc> createState() => _SlammerArenaDiscState();
}

class _SlammerArenaDiscState extends ConsumerState<SlammerArenaDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flyIn;
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
    // Hit feedback first — local remounts can clear [onFlyInComplete].
    widget.onLocalHitFeedback?.call();
    unawaited(ref.read(audioPlaybackProvider).play(kAudioCueSlamHit));
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

  Widget _discLayer() {
    switch (widget.phase) {
      case SlammerArenaPhase.flyIn:
        return LayoutBuilder(
          builder: (context, constraints) {
            final arena = Size(constraints.maxWidth, constraints.maxHeight);
            final impact = _impactOffset(arena);
            return AnimatedBuilder(
              animation: _flyIn,
              builder: (context, child) {
                final t = _flyIn.value;
                final fly = slamStrikeTravel(t);
                final scale = slamStrikeScale(t);
                final pos = Offset.lerp(widget.home, impact, fly)!;
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

  @override
  Widget build(BuildContext context) {
    final disc = _discLayer();
    final url = (widget.handImageUrl ?? '').trim();
    if (url.isEmpty) return disc;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        _RidingHand(
          fly: _flyIn,
          phase: widget.phase,
          home: widget.home,
          offset: widget.offset,
          qx: widget.qx,
          qy: widget.qy,
          qz: widget.qz,
          qw: widget.qw,
          aimX: widget.aimX,
          aimZ: widget.aimZ,
          size: widget.size,
          imageUrl: url,
          aspect: widget.handAspect,
          dock: widget.handDock,
          token: widget.token,
        ),
        disc,
      ],
    );
  }
}

/// Strike scale grows for the first half, then shrinks. The hand lets go
/// halfway through that shrink, holds, then fades out.
const double kHandReleaseFlyT = 0.5 + 0.5 * 0.5;

const int kHandHoldMs = 2000;
const int kHandFadeMs = 420;

class _RidingHand extends StatefulWidget {
  const _RidingHand({
    required this.fly,
    required this.phase,
    required this.home,
    required this.offset,
    required this.qx,
    required this.qy,
    required this.qz,
    required this.qw,
    required this.aimX,
    required this.aimZ,
    required this.size,
    required this.imageUrl,
    required this.aspect,
    required this.dock,
    required this.token,
  });

  final Animation<double> fly;
  final SlammerArenaPhase phase;
  final Offset home;
  final Offset offset;
  final double qx;
  final double qy;
  final double qz;
  final double qw;
  final double aimX;
  final double aimZ;
  final double size;
  final String imageUrl;
  final double aspect;
  final SlammerDockSide dock;
  final int token;

  @override
  State<_RidingHand> createState() => _RidingHandState();
}

class _RidingHandState extends State<_RidingHand>
    with SingleTickerProviderStateMixin {
  late final Ticker _clock;
  Duration _elapsed = Duration.zero;
  Duration _heldAt = Duration.zero;
  bool _held = false;
  bool _gone = false;
  Offset _stop = Offset.zero;
  double _stopScale = 1;
  double _stopQx = 0;
  double _stopQy = 0;
  double _stopQz = 0;
  double _stopQw = 1;
  Size _arena = Size.zero;

  @override
  void initState() {
    super.initState();
    _clock = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant _RidingHand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _held = false;
      _gone = false;
      _elapsed = Duration.zero;
      _heldAt = Duration.zero;
      _clock
        ..stop()
        ..start();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    final pastShrink = widget.phase != SlammerArenaPhase.flyIn ||
        widget.fly.value >= kHandReleaseFlyT;
    if (!_held && pastShrink && _arena != Size.zero) {
      _held = true;
      _heldAt = elapsed;
      final pose = _attached(_arena);
      _stop = pose.pos;
      _stopScale = pose.scale;
      _stopQx = pose.qx;
      _stopQy = pose.qy;
      _stopQz = pose.qz;
      _stopQw = pose.qw;
    }
    if (_held) {
      final since = elapsed - _heldAt;
      if (since.inMilliseconds >= kHandHoldMs + kHandFadeMs) {
        _gone = true;
        _clock.stop();
      }
    }
    if (mounted) setState(() {});
  }

  double get _fade {
    if (!_held) return 1;
    final into = (_elapsed - _heldAt).inMilliseconds - kHandHoldMs;
    if (into <= 0) return 1;
    if (into >= kHandFadeMs) return 0;
    return 1 - into / kHandFadeMs;
  }

  Offset _impact(Size arena) {
    final impactX = (widget.aimX * 0.35).clamp(-0.35, 0.35);
    final impactY = (widget.aimZ * 0.35).clamp(-0.35, 0.35);
    return Offset(impactX * arena.width * 0.5, impactY * arena.height * 0.5);
  }

  ({Offset pos, double scale, double qx, double qy, double qz, double qw})
      _attached(Size arena) {
    switch (widget.phase) {
      case SlammerArenaPhase.flyIn:
        final t = widget.fly.value;
        return (
          pos: Offset.lerp(widget.home, _impact(arena), slamStrikeTravel(t))!,
          scale: slamStrikeScale(t),
          qx: 0.0,
          qy: 0.0,
          qz: 0.0,
          qw: 1.0,
        );
      case SlammerArenaPhase.scatter:
      case SlammerArenaPhase.returnHome:
        return (
          pos: widget.offset,
          scale: 1.0,
          qx: widget.qx,
          qy: widget.qy,
          qz: widget.qz,
          qw: widget.qw,
        );
      case SlammerArenaPhase.atHome:
        return (
          pos: widget.home,
          scale: 1.0,
          qx: 0.0,
          qy: 0.0,
          qz: 0.0,
          qw: 1.0,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final arena = Size(constraints.maxWidth, constraints.maxHeight);
        _arena = arena;
        final live = _attached(arena);
        final pose = _held
            ? (
                pos: _stop,
                scale: _stopScale,
                qx: _stopQx,
                qy: _stopQy,
                qz: _stopQz,
                qw: _stopQw,
              )
            : live;
        return Opacity(
          opacity: _fade,
          child: Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: pose.pos,
              child: Transform.scale(
                scale: pose.scale,
                child: Transform(
                  alignment: Alignment.center,
                  transform: matrixFromQuat(pose.qx, pose.qy, pose.qz, pose.qw),
                  child: HandUnderSlammer(
                    disc: const SizedBox.shrink(),
                    paintDisc: false,
                    discSize: widget.size,
                    dock: widget.dock,
                    imageUrl: widget.imageUrl,
                    aspectWidthOverHeight: widget.aspect,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
