import 'package:flutter/material.dart';

import '../../core/app_bar/app_bar_registrar.dart';
import '../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/app_chrome.dart';

/// Body for `/sample` — chrome lives in [AppShell].
class SampleScreen extends StatelessWidget {
  const SampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBarRegistrar(
      items: const [
        AppBarTitle(
          text: 'Sample module',
          icon: Icons.widgets_outlined,
        ),
      ],
      child: AppChromePage(
        child: Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.widgets_outlined,
                  size: 64,
                  color: context.appColors.secondary,
                ),
                AppSpacing.gapMd,
                Text(
                  'Sample feature',
                  style: context.appTypography.h3,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapXs,
                Text(
                  'This screen is registered from lib/modules/sample/ '
                  'via the shared route sink. Use the drawer or back button '
                  'to navigate.',
                  textAlign: TextAlign.center,
                  style: context.appTypography.bodyMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
