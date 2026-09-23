import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';

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

    return AppChromeSection(
      title: 'Guest → Full Account',
      goldFrame: true,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upgrade to keep your data across devices, recover your account, '
            'and manage or delete it when you need to.',
            style: context.appTypography.bodySmall.copyWith(
              color: AppChrome.onSurfaceMuted,
            ),
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
