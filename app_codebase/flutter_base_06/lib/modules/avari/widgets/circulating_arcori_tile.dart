import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../kin/widgets/kin_lottie_preview.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../avari_models.dart';

/// One circulating design: disc, name, and mastery.
class CirculatingArcoriTile extends StatelessWidget {
  const CirculatingArcoriTile({
    required this.item,
    required this.onTap,
    super.key,
  });

  final AvariInventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            4,
            AppSpacing.xs,
            6,
          ),
          child: Column(
            children: [
              Expanded(child: CirculatingArcoriDisc(item: item, onTap: onTap)),
              AppSpacing.gapXxs,
              Text(
                item.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.appTypography.caption.copyWith(
                  color: AppChrome.onSurface,
                ),
              ),
              Text(
                item.masteryOverMintReach,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: context.appTypography.caption.copyWith(
                  color: AppChrome.accentGold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CirculatingArcoriDisc extends StatelessWidget {
  const CirculatingArcoriDisc({
    required this.item,
    required this.onTap,
    this.size,
    super.key,
  });

  final AvariInventoryItem item;
  final VoidCallback onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    if (size != null) {
      return GestureDetector(
        onTap: onTap,
        child: ArcoriCylinder(
          look: _look,
          size: size!,
          face: _face,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest.shortestSide;
        final fitted =
            (box / (1 + kArcoriThicknessFactor * 0.55)).clamp(1.0, box);
        return Center(
          child: ArcoriCylinder(
            look: _look,
            size: fitted,
            face: _face,
          ),
        );
      },
    );
  }

  ArcoriLook get _look => ArcoriLook(
        designId: item.designId,
        imageUrl: item.hasLottieFace ? null : item.imageUrl,
        colorHex: item.color,
      );

  Widget? get _face => item.hasLottieFace
      ? KinSceneStack(lottieUrl: item.lottieUrl, fit: BoxFit.cover)
      : null;
}
