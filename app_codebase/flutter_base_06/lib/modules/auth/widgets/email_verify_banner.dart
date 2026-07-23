import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/auth/auth_providers.dart';
import '../../../core/state/user/user_profile_provider.dart';
import '../../../core/theme/theme.dart';

/// Prompts full accounts that have not verified email yet.
class EmailVerifyBanner extends ConsumerStatefulWidget {
  const EmailVerifyBanner({super.key});

  @override
  ConsumerState<EmailVerifyBanner> createState() => _EmailVerifyBannerState();
}

class _EmailVerifyBannerState extends ConsumerState<EmailVerifyBanner> {
  bool _sending = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.profile;

    if (!auth.isAuthenticated ||
        auth.isGuest ||
        profile == null ||
        profile.emailVerified) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: AppSpacing.screenPaddingCompact.copyWith(top: AppSpacing.md),
      padding: AppSpacing.screenPaddingCompact,
      decoration: BoxDecoration(
        color: context.appColorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppButtonMetrics.radius),
        border: Border.all(color: context.appColorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Verify your email',
            style: context.appTypography.subtitle,
          ),
          AppSpacing.gapSm,
          Text(
            'We sent a verification link to ${profile.email}. '
            'Verify to confirm account ownership.',
            style: context.appTypography.bodySmall,
          ),
          if (_statusMessage != null) ...[
            AppSpacing.gapSm,
            Text(
              _statusMessage!,
              style: context.appTypography.bodySmall,
            ),
          ],
          AppSpacing.gapMd,
          FilledButton(
            style: context.appButtons.primary.filled,
            onPressed: _sending ? null : _onResend,
            child: Text(_sending ? 'Sending…' : 'Resend verification email'),
          ),
        ],
      ),
    );
  }

  Future<void> _onResend() async {
    setState(() {
      _sending = true;
      _statusMessage = null;
    });
    final ok =
        await ref.read(userProfileProvider.notifier).resendEmailVerification();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _statusMessage = ok
          ? 'Verification email sent (if mail is configured).'
          : (ref.read(userProfileProvider).errorMessage ??
              'Could not resend verification email.');
    });
  }
}
