import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';

/// Region or place art, with a dark lower scrim so a label can sit on it.
class VeloraImageCover extends StatelessWidget {
  const VeloraImageCover({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.surfaceDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => ColoredBox(color: AppChrome.fieldFill),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ink.withValues(alpha: 0.08),
                ink.withValues(alpha: 0.18),
                ink.withValues(alpha: 0.9),
              ],
              stops: const [0.0, 0.42, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
