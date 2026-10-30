import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/auth/auth_providers.dart';
import '../../../core/state/user/user_profile_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../../avari/avari_notifier.dart';
import '../../avari/widgets/profile_face_avatar.dart';

/// Profile header with the Kin face, username, email, and account type.
class AccountProfileCard extends ConsumerStatefulWidget {
  const AccountProfileCard({super.key});

  @override
  ConsumerState<AccountProfileCard> createState() => _AccountProfileCardState();
}

class _AccountProfileCardState extends ConsumerState<AccountProfileCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAvariLoaded());
  }

  void _ensureAvariLoaded() {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.isGuest) return;
    final avari = ref.read(avariProfileProvider);
    if (!avari.loaded && !avari.isLoading) {
      ref.read(avariProfileProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isAuthenticated || auth.isGuest) return const SizedBox.shrink();

    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.profile;
    final avariProfile = ref.watch(avariProfileProvider).profile;
    final faceUrl = resolveProfileFaceUrl(
      kinLottieUrl: avariProfile?.kin?.lottieUrl,
      identityAvatarUrl: avariProfile?.identity.avatarUrl,
      userAvatarUrl: profile?.avatarUrl,
    );

    return AppChromeSection(
      title: 'Profile',
      mark: const AppMarkIcon(AppMarks.avari),
      goldFrame: true,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (profileState.isLoading && profile == null)
            const Center(child: CircularProgressIndicator())
          else if (profile != null)
            _ProfileBody(
              username: profile.username,
              email: profile.email,
              accountType: profile.accountType,
              faceUrl: faceUrl,
            )
          else
            Text(
              profileState.errorMessage ?? 'Could not load profile',
              style: context.appTypography.body.copyWith(
                color: context.appColors.red,
              ),
            ),
          if (profileState.errorMessage != null && profile != null) ...[
            AppSpacing.gapSm,
            Text(
              profileState.errorMessage!,
              style: context.appTypography.bodySmall.copyWith(
                color: context.appColors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.username,
    required this.email,
    required this.accountType,
    required this.faceUrl,
  });

  final String username;
  final String email;
  final String accountType;
  final String? faceUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ProfileFaceAvatar(
          avatarUrl: faceUrl,
          size: 80,
        ),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: context.appTypography.subtitle.copyWith(
                  color: AppChrome.onSurface,
                ),
              ),
              AppSpacing.gapXxs,
              Text(
                email,
                style: context.appTypography.bodyMuted.copyWith(
                  color: AppChrome.onSurfaceMuted,
                ),
              ),
              AppSpacing.gapSm,
              _AccountTypeChip(label: accountType),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountTypeChip extends StatelessWidget {
  const _AccountTypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isGuest = label.toLowerCase() == 'guest';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppChrome.fieldFill,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: isGuest ? AppChrome.panelBorder : AppChrome.panelBorderGold,
        ),
      ),
      child: Text(
        label,
        style: context.appTypography.bodySmall.copyWith(
          color: AppChrome.onSurface,
        ),
      ),
    );
  }
}
