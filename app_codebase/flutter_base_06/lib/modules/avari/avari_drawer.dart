import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_navigation.dart';
import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/state/user/user_profile_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../kin/kin_notifier.dart';
import 'avari_notifier.dart';
import 'widgets/profile_face_avatar.dart';

void registerAvariDrawer(AppDrawerSink drawer) {
  drawer.setHeader(
    AppDrawerHeader(builder: (context) => const AvariDrawerHeader()),
  );
}

/// Module-owned drawer header — center avatar opens Avari profile.
class AvariDrawerHeader extends ConsumerStatefulWidget {
  const AvariDrawerHeader({super.key});

  @override
  ConsumerState<AvariDrawerHeader> createState() => _AvariDrawerHeaderState();
}

class _AvariDrawerHeaderState extends ConsumerState<AvariDrawerHeader> {
  static const double _size = 72;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAvariLoaded());
  }

  void _ensureAvariLoaded() {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;
    final avari = ref.read(avariProfileProvider);
    if (!avari.loaded && !avari.isLoading) {
      ref.read(avariProfileProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userProfile = ref.watch(userProfileProvider).profile;
    final avariProfile = ref.watch(avariProfileProvider).profile;

    // Prefer Kin Lottie face (same as Avari profile identity); user profile
    // skips guests and can lag behind claim until refresh.
    final avatarUrl = () {
      final kinLottie = avariProfile?.kin?.lottieUrl?.trim() ?? '';
      if (kinLottie.isNotEmpty) return kinLottie;
      final identity = avariProfile?.identity.avatarUrl?.trim() ?? '';
      if (identity.isNotEmpty) return identity;
      return userProfile?.avatarUrl;
    }();

    final name = () {
      final fromAvari = avariProfile?.identity.displayName.trim() ?? '';
      if (fromAvari.isNotEmpty) return fromAvari;
      final fromUser = userProfile?.username.trim() ?? '';
      if (fromUser.isNotEmpty) return fromUser;
      return auth.isAuthenticated ? 'Avari' : 'Sign in';
    }();

    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated &&
          (previous == null || !previous.isAuthenticated)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAvariLoaded());
      }
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: InkWell(
        onTap: () {
          final scaffold = Scaffold.maybeOf(context);
          scaffold?.closeDrawer();
          final current = Nav.matchedLocation(context).split('?').first;
          if (current == AppPaths.avari) {
            // Already on profile — force-refresh Arcori stats (push is a no-op).
            if (auth.isAuthenticated) {
              ref.read(avariProfileProvider.notifier).load(force: true);
            }
            ref.read(kinActiveSaveProvider.notifier).refresh();
            return;
          }
          Nav.pushFromDrawer(
            context,
            AppPaths.avari,
            scaffold: scaffold,
          );
        },
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppChrome.accentGold,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  child: ProfileFaceAvatar(
                    avatarUrl: avatarUrl,
                    size: _size,
                  ),
                ),
              ),
              AppSpacing.gapXs,
              Text(
                name,
                style: context.appTypography.title.copyWith(
                  color: AppChrome.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                auth.isAuthenticated ? 'Avari profile' : 'Open Avari',
                style: context.appTypography.caption.copyWith(
                  color: AppChrome.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
