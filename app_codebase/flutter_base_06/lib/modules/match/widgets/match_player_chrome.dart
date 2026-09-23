import 'package:flutter/material.dart';

import '../../../core/http/media_url.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_visuals.dart';
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
    this.avatarUrl,
    this.isActive = false,
    this.isSelf = false,
    this.avatarKey,
    this.slammerKey,
    this.slammerLook,
    this.slammerLottieUrl,
    this.showSlammer = true,
    this.slammerDock = SlammerDockSide.top,
    super.key,
  });

  final String username;
  final String? avatarUrl;
  final bool isActive;
  final bool isSelf;

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
    final hud = context.appHud;
    final surfaces = context.appSurfaces;
    final name = username.trim().isEmpty ? '?' : username.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final resolved = resolveMediaUrl(avatarUrl);
    final ring = isActive ? hud.armed : surfaces.frameGold;

    final chip = AppHudGlassChip(
      emphasized: isActive,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: avatarKey,
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: isActive ? 2.5 : 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: resolved.isNotEmpty
                ? Image.network(
                    resolved,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _Initials(initial: initial),
                  )
                : _Initials(initial: initial),
          ),
          AppSpacing.gapXs,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 88),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.appTypography.label.copyWith(
                color: hud.onGlass,
                fontWeight:
                    isSelf || isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    final resting = _restingSlammerSlot();
    if (resting == null) return chip;

    const gap = 6.0;
    switch (slammerDock) {
      case SlammerDockSide.top:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [resting, const SizedBox(height: gap), chip],
        );
      case SlammerDockSide.bottom:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [chip, const SizedBox(height: gap), resting],
        );
      case SlammerDockSide.left:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [resting, const SizedBox(width: gap), chip],
        );
      case SlammerDockSide.right:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [chip, const SizedBox(width: gap), resting],
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
          ? KinSceneStack(
              lottieUrl: slammerLottieUrl,
              fit: BoxFit.cover,
            )
          : null,
    );
    return Visibility(
      visible: showSlammer,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      maintainInteractivity: false,
      child: KeyedSubtree(
        key: slammerKey,
        child: disc,
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final hud = context.appHud;
    return ColoredBox(
      color: context.appSurfaces.glassHud,
      child: Center(
        child: Text(
          initial,
          style: context.appTypography.h3.copyWith(color: hud.onGlass),
        ),
      ),
    );
  }
}
