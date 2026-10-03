import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../kin/widgets/kin_lottie_preview.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../avari_models.dart';

/// Inventory chip — same [ArcoriCylinder] as the match stack.
/// Face art is webp ([AvariInventoryItem.imageUrl]) or Lottie ([lottieUrl]/file).
class InventoryFaceChip extends StatelessWidget {
  const InventoryFaceChip({
    required this.item,
    this.lottieFile,
    this.captionOverride,
    this.onTap,
    super.key,
  });

  final AvariInventoryItem item;
  final File? lottieFile;

  /// When set, replaces the mastery / mint-reach caption (e.g. Trove gen).
  final String? captionOverride;
  final VoidCallback? onTap;

  static const double size = 64;
  static const double chipWidth = size + AppSpacing.md;

  /// Approx height: disc + two caption lines + gaps (3-row scroll layout).
  static const double chipHeight = size + 52;

  @override
  Widget build(BuildContext context) {
    final useLottie = item.hasLottieFace || lottieFile != null;
    final caption = captionOverride ?? item.masteryOverMintReach;
    final column = SizedBox(
      width: chipWidth,
      height: chipHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArcoriCylinder(
            look: ArcoriLook(
              designId: item.designId,
              imageUrl: useLottie ? null : item.imageUrl,
              colorHex: item.color,
            ),
            size: size,
            face: useLottie
                ? KinSceneStack(
                    lottieUrl: item.lottieUrl,
                    file: lottieFile,
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          AppSpacing.gapXxs,
          Text(
            item.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.appTypography.caption,
          ),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.appTypography.caption.copyWith(
              color: context.appColorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return column;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: column,
    );
  }
}
