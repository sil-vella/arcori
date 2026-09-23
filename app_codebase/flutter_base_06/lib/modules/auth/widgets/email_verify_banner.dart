import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/auth/auth_providers.dart';
import '../../../core/state/user/user_profile_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';

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

    return AppChromeSection(
      title: 'Verify your email',
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We sent a verification link to ${profile.email}. '
            'Verify to confirm account ownership.',
            style: context.appTypography.bodySmall.copyWith(
              color: AppChrome.onSurfaceMuted,
            ),
          ),
          if (_statusMessage != null) ...[
            AppSpacing.gapSm,
            Text(
              _statusMessage!,
              style: context.appTypography.bodySmall.copyWith(
                color: AppChrome.onSurface,
              ),
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
