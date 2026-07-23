import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';

/// Prompts signed-in guests to upgrade to a full account.
class GuestConvertBanner extends ConsumerWidget {
  const GuestConvertBanner({
    super.key,
    required this.onConvertTap,
  });

  final VoidCallback onConvertTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isAuthenticated || !auth.isGuest) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: AppSpacing.screenPaddingCompact.copyWith(top: AppSpacing.md),
      padding: AppSpacing.screenPaddingCompact,
      decoration: BoxDecoration(
        color: context.appColorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppButtonMetrics.radius),
        border: Border.all(color: context.appColorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Guest → Full Account',
            style: context.appTypography.subtitle,
          ),
          AppSpacing.gapSm,
          Text(
            'Upgrade to keep your data across devices, recover your account, '
            'and manage or delete it when you need to.',
            style: context.appTypography.bodySmall,
          ),
          AppSpacing.gapMd,
          FilledButton(
            style: context.appButtons.primary.filled,
            onPressed: onConvertTap,
            child: const Text('Convert to full account'),
          ),
        ],
      ),
    );
  }
}
