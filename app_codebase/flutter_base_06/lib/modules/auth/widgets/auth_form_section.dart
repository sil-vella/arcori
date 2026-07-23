import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Auth form section body — padding, subtitle, optional error (no scaffold).
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
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(subtitle, style: context.appTypography.bodyMuted),
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
      ),
    );
  }
}
