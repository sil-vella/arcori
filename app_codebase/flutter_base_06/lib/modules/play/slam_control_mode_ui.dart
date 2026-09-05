import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'game_controls_prefs.dart';

/// Labels, icons, and captions for [SlamControlMode] — SSOT for Game Controls
/// and the match HUD.
extension SlamControlModeUi on SlamControlMode {
  String get label => switch (this) {
        SlamControlMode.accel => 'Phone motion',
        SlamControlMode.touch => 'Touch',
      };

  IconData get icon => switch (this) {
        SlamControlMode.accel => Icons.screen_rotation,
        SlamControlMode.touch => Icons.swipe_down,
      };

  String get caption => switch (this) {
        SlamControlMode.accel => 'Tilt to aim. Shake to slam.',
        SlamControlMode.touch => 'Drag to aim. Swipe down to slam.',
      };
}

/// Clear in-match readout of the equipped slam control setting.
class SlamControlModeIndicator extends StatelessWidget {
  const SlamControlModeIndicator({
    super.key,
    required this.mode,
  });

  final SlamControlMode mode;

  @override
  Widget build(BuildContext context) {
    final scheme = context.appColorScheme;
    return Semantics(
      label: 'Slam controls: ${mode.label}. ${mode.caption}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppButtonMetrics.radius),
          border: Border.all(color: scheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                mode.icon,
                size: 32,
                color: scheme.onPrimaryContainer,
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: context.appTypography.subtitle,
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      mode.caption,
                      style: context.appTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
