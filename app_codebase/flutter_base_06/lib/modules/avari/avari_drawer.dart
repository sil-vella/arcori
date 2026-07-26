import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http/media_url.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_drawer_contract.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/state/user/user_profile_provider.dart';
import '../../core/theme/theme.dart';

void registerAvariDrawer(AppDrawerSink drawer) {
  drawer.setHeader(
    AppDrawerHeader(builder: (context) => const AvariDrawerHeader()),
  );
}

/// Module-owned drawer header — center avatar opens Avari profile.
class AvariDrawerHeader extends ConsumerWidget {
  const AvariDrawerHeader({super.key});

  static const double _size = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profile = ref.watch(userProfileProvider).profile;
    final scheme = context.appColorScheme;
    final url = resolveMediaUrl(profile?.avatarUrl);
    final name = (profile?.username != null && profile!.username.isNotEmpty)
        ? profile.username
        : (auth.isAuthenticated ? 'Avari' : 'Sign in');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: InkWell(
        onTap: () => Nav.pushFromDrawer(
          context,
          AppPaths.avari,
          scaffold: Scaffold.maybeOf(context),
        ),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              SizedBox(
                width: _size,
                height: _size,
                child: ClipOval(
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: url.isEmpty
                        ? Icon(
                            Icons.person_outline,
                            size: AppSpacing.xl,
                            color: scheme.onSurfaceVariant,
                          )
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            width: _size,
                            height: _size,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.person_outline,
                              size: AppSpacing.xl,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
              ),
              AppSpacing.gapXs,
              Text(
                name,
                style: context.appTypography.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                auth.isAuthenticated ? 'Avari profile' : 'Open Avari',
                style: context.appTypography.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
