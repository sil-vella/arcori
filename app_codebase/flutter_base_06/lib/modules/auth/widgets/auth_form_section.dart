import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';

/// Auth form section body — subtitle, optional error (no scaffold).
class AuthFormSection extends StatelessWidget {
  const AuthFormSection({
    super.key,
    required this.subtitle,
    required this.child,
    this.errorMessage,
  });

  final String subtitle;
  final Widget child;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          subtitle,
          style: context.appTypography.bodyMuted.copyWith(
            color: AppChrome.onSurfaceMuted,
          ),
        ),
        if (errorMessage != null && errorMessage!.isNotEmpty) ...[
          AppSpacing.gapSm,
          Text(
            errorMessage!,
            style: context.appTypography.body.copyWith(
              color: context.appColors.red,
            ),
          ),
        ],
        AppSpacing.gapMd,
        child,
      ],
    );
  }
}
