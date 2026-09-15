import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
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
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: context.appTypography.body),
              AppSpacing.gapMd,
              FilledButton(
                onPressed: () => Nav.push(context, AppPaths.account),
                child: const Text('Account'),
              ),
            ],
          ),
        ),
      );
    }

    // Rebuild when store changes.
    return ValueListenableBuilder<int>(
      valueListenable: AchievementsCatalogStore.changeVersion,
      builder: (context, _, __) {
        // Past unlocks only — active Daily Goals / Tasks live under Tasks.
        final entries = AchievementsCatalogStore.all
            .where((e) => AchievementsCatalogStore.isUnlocked(e.id))
            .toList();
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Text(
                'No past achievements yet.\n'
                'Completed goals, tasks, and match unlocks appear here.',
                textAlign: TextAlign.center,
                style: context.appTypography.body,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              Text(
                'Past achievements from goals, tasks, and matches.',
                style: context.appTypography.bodySmall,
              ),
              AppSpacing.gapMd,
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) AppSpacing.gapSm,
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.emoji_events,
                      color: context.appColorScheme.primary,
                    ),
                    title: Text(
                      entries[i].achievementName,
                      style: context.appTypography.body,
                    ),
                    subtitle: Text(
                      entries[i].description,
                      style: context.appTypography.bodySmall,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
