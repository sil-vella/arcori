import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../kin/widgets/kin_lottie_preview.dart';
import 'arcori_cylinder.dart';
import 'arcori_look.dart';
import 'slammer_strike_overlay.dart';

/// Where the resting slammer sits relative to the avatar (toward the board).
enum SlammerDockSide { top, bottom, left, right }

/// Avatar + username chip for match play chrome (Template 002 slots).
///
/// Each seat has one equipped slammer: visible at rest beside the avatar from
/// match init; hidden (same slot kept) while that seat’s arena anim runs.
class MatchPlayerChrome extends StatelessWidget {
  const MatchPlayerChrome({
    required this.username,
    this.isActive = false,
    this.isSelf = false,
    this.avatarKey,
    this.arcoriLook,
    this.arcoriLottieUrl,
    this.slammerKey,
    this.slammerLook,
    this.slammerLottieUrl,
    this.showSlammer = true,
    this.slammerDock = SlammerDockSide.top,
    super.key,
  });

  final String username;
  final bool isActive;
  final bool isSelf;

  /// Arcori this seat is playing. Replaces the profile mark.
  final ArcoriLook? arcoriLook;
  final String? arcoriLottieUrl;

  /// Optional key on the avatar circle.
  final Key? avatarKey;

  /// Key on the resting slammer (fly-in / return docking).
  final Key? slammerKey;

  /// Equipped slammer face — shown at rest beside the avatar.
  final ArcoriLook? slammerLook;
  final String? slammerLottieUrl;

  /// When false, hide the resting disc while arena anim owns this seat’s slammer.
  /// Layout size is maintained so dock coords stay stable.
  final bool showSlammer;

  /// Side of the chrome facing the board (slammer docks here).
  final SlammerDockSide slammerDock;

  static const double avatarSize = 52;
  static final double slammerSize = avatarSize * kSlammerToArcoriScale;

  /// Self (bottom chrome): dock above avatar, toward the board.
  static const SlammerDockSide dockSelf = SlammerDockSide.top;

  /// Single opponent (top): dock below avatar, toward the board.
  static const SlammerDockSide dockOpponentTop = SlammerDockSide.bottom;

  /// Left opponent: dock toward board (right of avatar).
  static const SlammerDockSide dockOpponentLeft = SlammerDockSide.right;

  /// Right opponent: dock toward board (left of avatar).
  static const SlammerDockSide dockOpponentRight = SlammerDockSide.left;

  @override
  Widget build(BuildContext context) {
    final name = username.trim().isEmpty ? '?' : username.trim();
    final chip = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlayedArcoriFace(
          key: avatarKey,
          look: arcoriLook,
          lottieUrl: arcoriLottieUrl,
          inPlay: isActive,
          size: avatarSize,
        ),
        AppSpacing.gapXs,
        _UsernameRing(name: name, current: isActive, self: isSelf),
      ],
    );

    final resting = _restingSlammerSlot();
    if (resting == null) return chip;

    const gap = 6.0;
    switch (slammerDock) {
      case SlammerDockSide.top:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            resting,
            const SizedBox(height: gap),
            chip,
          ],
        );
      case SlammerDockSide.bottom:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip,
            const SizedBox(height: gap),
            resting,
          ],
        );
      case SlammerDockSide.left:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            resting,
            const SizedBox(width: gap),
            chip,
          ],
        );
      case SlammerDockSide.right:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chip,
            const SizedBox(width: gap),
            resting,
          ],
        );
    }
  }

  /// Rest slot always reserved when a look exists; [showSlammer] only toggles paint.
  Widget? _restingSlammerSlot() {
    final look = slammerLook;
    if (look == null) return null;
    final useLottie = (slammerLottieUrl ?? '').trim().isNotEmpty;
    final disc = ArcoriCylinder(
      look: ArcoriLook(
        designId: look.designId,
        imageUrl: useLottie ? null : look.imageUrl,
        colorHex: look.colorHex,
      ),
      size: slammerSize,
      faceUp: true,
      showThickness: true,
      face: useLottie
          ? KinSceneStack(lottieUrl: slammerLottieUrl, fit: BoxFit.cover)
          : null,
    );
    return Visibility(
      visible: showSlammer,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      maintainInteractivity: false,
      child: KeyedSubtree(key: slammerKey, child: disc),
    );
  }
}

/// Played Arcori. The outer border turns green while this seat is in play.
class _PlayedArcoriFace extends StatelessWidget {
  const _PlayedArcoriFace({
    super.key,
    required this.look,
    required this.inPlay,
    required this.size,
    this.lottieUrl,
  });

  final ArcoriLook? look;
  final String? lottieUrl;
  final bool inPlay;
  final double size;

  @override
  Widget build(BuildContext context) {
    final gold = AppSurfaces.frameGold(Brightness.dark);
    final live = context.appHud.armed;
    final border = inPlay ? live : gold;
    final useLottie = (lottieUrl ?? '').trim().isNotEmpty;
    final face = look;
    return Container(
      width: size + 6,
      height: size + 6,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: inPlay ? 2.5 : 1.5),
        boxShadow: [
          if (inPlay)
            BoxShadow(color: live.withValues(alpha: 0.7), blurRadius: 12),
        ],
      ),
      child: face == null
          ? const SizedBox.shrink()
          : ArcoriCylinder(
              look: ArcoriLook(
                designId: face.designId,
                imageUrl: useLottie ? null : face.imageUrl,
                colorHex: face.colorHex,
              ),
              size: size,
              faceUp: true,
              showThickness: false,
              face: useLottie
                  ? KinSceneStack(lottieUrl: lottieUrl, fit: BoxFit.cover)
                  : null,
            ),
    );
  }
}

/// Gold rim around the name, a diamond at the bottom, and a green dot in play.
class _UsernameRing extends StatelessWidget {
  const _UsernameRing({
    required this.name,
    required this.current,
    required this.self,
  });

  final String name;
  final bool current;
  final bool self;

  @override
  Widget build(BuildContext context) {
    final gold = AppSurfaces.frameGold(Brightness.dark);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 112),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundDark.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: gold, width: 1.5),
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.appTypography.label.copyWith(
              color: AppColors.onSurfaceDark,
              fontWeight: current || self ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
        if (current)
          Positioned(
            top: -4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.appHud.armed,
                border: Border.all(color: AppColors.backgroundDark, width: 1),
              ),
            ),
          ),
        Positioned(
          bottom: -5,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: gold,
                border: Border.all(color: AppColors.backgroundDark, width: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
