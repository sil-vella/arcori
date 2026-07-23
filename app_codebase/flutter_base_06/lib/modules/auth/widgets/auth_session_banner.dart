import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';

/// Compact session status for auth screens.
class AuthSessionBanner extends ConsumerWidget {
  const AuthSessionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isAuthenticated) return const SizedBox.shrink();

    final label = auth.isGuest
        ? 'Signed in as guest'
        : 'Signed in';

    return Container(
      padding: AppSpacing.screenPaddingCompact,
      decoration: BoxDecoration(
        color: context.appColorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppButtonMetrics.radius),
        border: Border.all(color: context.appColorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.appTypography.subtitle),
          AppSpacing.gapXxs,
          Text(
            auth.userId ?? 'unknown',
            style: context.appTypography.monospaceSmall,
          ),
        ],
      ),
    );
  }
}
