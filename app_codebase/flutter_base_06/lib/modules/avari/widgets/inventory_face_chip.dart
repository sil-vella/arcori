import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../kin/kin_backgrounds.dart';
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
    super.key,
  });

  final AvariInventoryItem item;
  final File? lottieFile;

  /// When set, replaces the mastery / mint-reach caption (e.g. Trove gen).
  final String? captionOverride;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final useLottie = item.hasLottieFace || lottieFile != null;
    final caption = captionOverride ?? item.masteryOverMintReach;
    return SizedBox(
      width: _size + AppSpacing.md,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArcoriCylinder(
            look: ArcoriLook(
              designId: item.designId,
              imageUrl: useLottie ? null : item.imageUrl,
              colorHex: item.color,
            ),
            size: _size,
            face: useLottie
                ? KinSceneStack(
                    lottieUrl: item.lottieUrl,
                    file: lottieFile,
                    scene: KinBackgroundScene.fromClaimJson(item.background),
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
  }
}
