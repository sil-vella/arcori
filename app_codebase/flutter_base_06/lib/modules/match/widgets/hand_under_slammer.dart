import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/http/media_url.dart';

/// Where the resting slammer sits relative to the avatar (toward the board).
enum SlammerDockSide { top, bottom, left, right }

/// Palm point in every current hand image (fingers left, wrist right).
const double kHandPalmX = 0.42;
const double kHandPalmY = 0.56;

/// Hand slot width relative to the resting disc.
/// 1.75, then doubled, then reduced by a third.
const double kHandWidthOverDisc = 3.5 * 2 / 3;

/// How far the palm sits from disc center toward the seat's right, in disc widths.
const double kPalmTowardSeatRight = 0.18;

/// Extra screen shift, in disc widths. Left is −x, down is +y.
const double kHandNudgeLeft = 0.32;
const double kHandNudgeDown = 0.12;

/// Extra drop for the local player's hand only.
const double kHandUserExtraDown = 0.18;

/// How far a side hand sits toward that player's seat, in disc widths.
const double kHandSeatOut = 0.24;

/// Upward shift for the left-seat hand, in disc widths.
const double kHandLeftLift = 0.28;

/// Downward shift for the right-seat hand, in disc widths.
const double kHandRightDrop = 0.10;

/// Local hand is one sixth larger than the other seats.
const double kHandUserScale = 1 + 1 / 6;

/// Screen shift in disc widths. +x is right, +y is down.
Offset handScreenNudge(SlammerDockSide dock) {
  switch (dock) {
    case SlammerDockSide.top:
      return Offset(-kHandNudgeLeft, kHandNudgeDown + kHandUserExtraDown);
    case SlammerDockSide.bottom:
      return Offset(0, kHandNudgeDown - kHandSeatOut);
    case SlammerDockSide.right:
      return Offset(
        -(kHandNudgeLeft + kHandSeatOut),
        kHandNudgeDown - kHandLeftLift,
      );
    case SlammerDockSide.left:
      return Offset(kHandSeatOut, kHandNudgeDown + kHandRightDrop);
  }
}

/// Screen angle of the hand. Art wrist points +x before this.
///
/// The local player (top) is vertical, wrist down. Flutter rotation is
/// clockwise. The left-seat player ([SlammerDockSide.right], slammer on the
/// right of that avatar) is 90° clockwise from the local hand. The right-seat
/// player ([SlammerDockSide.left]) is 270° clockwise from it.
double handWristRadians(SlammerDockSide dock) {
  const upright = math.pi / 2;
  switch (dock) {
    case SlammerDockSide.top:
    case SlammerDockSide.bottom:
      return upright;
    case SlammerDockSide.right:
      return upright + math.pi / 2;
    case SlammerDockSide.left:
      return upright + 3 * math.pi / 2;
  }
}

/// Direction from disc center toward that seat's right.
///
/// Top dock is the local player. Their right is +x. Bottom faces the other
/// way, so their right is −x. A slammer on the right of its avatar faces +x,
/// so that seat's right is +y. A slammer on the left faces −x, so that
/// seat's right is −y.
double handSeatRightRadians(SlammerDockSide dock) {
  switch (dock) {
    case SlammerDockSide.top:
      return 0;
    case SlammerDockSide.bottom:
      return math.pi;
    case SlammerDockSide.right:
      return math.pi / 2;
    case SlammerDockSide.left:
      return -math.pi / 2;
  }
}

/// Palm under the right side of [disc]. The local forearm is vertical.
///
/// The disc stays upright and on top. The key stays on the disc so strike
/// docking still measures the slammer, not the hand.
class HandUnderSlammer extends StatelessWidget {
  const HandUnderSlammer({
    required this.disc,
    required this.discSize,
    required this.dock,
    this.imageUrl,
    this.aspectWidthOverHeight = 768 / 512,
    this.discKey,
    this.paintDisc = true,
    super.key,
  });

  final Widget disc;
  final double discSize;
  final SlammerDockSide dock;
  final String? imageUrl;
  final double aspectWidthOverHeight;
  final Key? discKey;

  /// False paints only the hand, for the slam ride that is separate from the disc.
  final bool paintDisc;

  @override
  Widget build(BuildContext context) {
    final keyed = KeyedSubtree(key: discKey, child: disc);
    final url = (imageUrl ?? '').trim();
    if (url.isEmpty) return keyed;

    final angle = handWristRadians(dock);
    final seatRightAngle = handSeatRightRadians(dock);
    final seatRight = Offset(
      math.cos(seatRightAngle),
      math.sin(seatRightAngle),
    );
    final userScale = dock == SlammerDockSide.top ? kHandUserScale : 1.0;
    final width = discSize * kHandWidthOverDisc * userScale;
    final height = width / aspectWidthOverHeight;
    final palmInHand = Offset(kHandPalmX * width, kHandPalmY * height);
    final nudge = handScreenNudge(dock) * discSize;
    final palmOnDisc = Offset(discSize / 2, discSize / 2) +
        seatRight * (discSize * kPalmTowardSeatRight) +
        nudge;
    final topLeft = palmOnDisc - palmInHand;

    return SizedBox(
      width: discSize,
      height: discSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: topLeft.dx,
            top: topLeft.dy,
            width: width,
            height: height,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: angle,
                alignment: Alignment(
                  kHandPalmX * 2 - 1,
                  kHandPalmY * 2 - 1,
                ),
                child: _HandArt(path: url),
              ),
            ),
          ),
          if (paintDisc) Positioned.fill(child: keyed),
        ],
      ),
    );
  }
}

class _HandArt extends StatefulWidget {
  const _HandArt({required this.path});

  final String path;

  @override
  State<_HandArt> createState() => _HandArtState();
}

class _HandArtState extends State<_HandArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _image() {
    const fit = BoxFit.contain;
    if (isBundleAssetMedia(widget.path)) {
      return Image.asset(
        bundleAssetPath(widget.path),
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    final url = resolveMediaUrl(widget.path);
    if (url.isEmpty) return const SizedBox.shrink();
    return Image.network(
      url,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final wave = (math.sin(_pulse.value * math.pi * 2) + 1) / 2;
        final opacity = 0.1 + (0.6 - 0.1) * wave;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: opacity,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: _image(),
                ),
              ),
            ),
            Opacity(opacity: opacity, child: _image()),
          ],
        );
      },
    );
  }
}
