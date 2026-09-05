import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../avari_models.dart';

/// Inventory chip — same [ArcoriCylinder] as the match stack.
class InventoryFaceChip extends StatelessWidget {
  const InventoryFaceChip({required this.item, super.key});

  final AvariInventoryItem item;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size + AppSpacing.md,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArcoriCylinder(
            look: ArcoriLook(
              designId: item.designId,
              imageUrl: item.imageUrl,
              colorHex: item.color,
            ),
            size: _size,
          ),
          AppSpacing.gapXxs,
          Text(
            item.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.appTypography.caption,
          ),
        ],
      ),
    );
  }
}
