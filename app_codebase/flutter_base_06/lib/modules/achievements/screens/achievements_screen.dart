import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../achievements_bootstrap.dart';
import '../achievements_catalog_store.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Sign in to view achievements';
      });
      return;
    }
    await hydrateAchievementsCatalog(ref);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Achievements', icon: Icons.emoji_events_outlined),
      ],
      child: AppChromePage(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const AppChromeCentered(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppChromeCentered(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: context.appTypography.body.copyWith(
                color: AppChrome.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapMd,
            FilledButton(
              onPressed: () => Nav.push(context, AppPaths.account),
              child: const Text('Account'),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: AchievementsCatalogStore.changeVersion,
      builder: (context, _, __) {
        final entries = AchievementsCatalogStore.all
            .where((e) => AchievementsCatalogStore.isUnlocked(e.id))
            .toList();
        if (entries.isEmpty) {
          return AppChromeCentered(
            child: Text(
              'No past achievements yet.\n'
              'Completed goals, tasks, and match unlocks appear here.',
              textAlign: TextAlign.center,
              style: context.appTypography.body.copyWith(
                color: AppChrome.onSurfaceMuted,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppChromePage.topClearance(context) + AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              AppChromeSection(
                title: 'Past unlocks',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Past achievements from goals, tasks, and matches.',
                      style: context.appTypography.bodySmall.copyWith(
                        color: AppChrome.onSurfaceMuted,
                      ),
                    ),
                    AppSpacing.gapMd,
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0) AppSpacing.gapSm,
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppChrome.fieldFill.withValues(alpha: 0.55),
                          borderRadius:
                              BorderRadius.circular(AppSurfaces.exhibitRadius),
                          border: Border.all(color: AppChrome.panelBorder),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.emoji_events,
                            color: AppChrome.accentGold,
                          ),
                          title: Text(
                            entries[i].achievementName,
                            style: context.appTypography.body.copyWith(
                              color: AppChrome.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            entries[i].description,
                            style: context.appTypography.bodySmall.copyWith(
                              color: AppChrome.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
