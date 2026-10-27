import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../circulating_browse.dart';
import 'arcori_container_bank.dart';

/// Tappable canisters for the circulating screen. Larger than the profile row.
class ArcoriCanisterGrid extends StatelessWidget {
  const ArcoriCanisterGrid({
    required this.canisters,
    required this.onTap,
    super.key,
  });

  final List<CirculatingCanister> canisters;
  final ValueChanged<CirculatingCanister> onTap;

  /// Twice the profile card, so a canister is easy to tap in the grid.
  static const double artWidth = ArcoriCanisterMark.profileArtWidth * 2;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.md,
      children: [
        for (final canister in canisters)
          ArcoriCanisterMark(
            key: ValueKey('circulating-canister-${canister.index}'),
            artWidth: artWidth,
            showProgress: canister.filling,
            filled: canister.filled,
            tapLabel: 'Tap to open',
            onTap: () => onTap(canister),
          ),
      ],
    );
  }
}
