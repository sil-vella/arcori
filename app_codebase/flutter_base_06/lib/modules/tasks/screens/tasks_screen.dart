import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../tasks_bootstrap.dart';
import '../tasks_models.dart';
import '../tasks_store.dart';

/// Active Daily Goals + Tasks with live progress. Past unlocks live under Achievements.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
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
        _error = 'Sign in to view daily goals and tasks';
      });
      return;
    }
    await hydrateTasks(ref);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _openTask(TaskCatalogEntry entry) {
    Nav.push(
      context,
      '${AppPaths.taskDetail}?id=${Uri.encodeComponent(entry.id)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Tasks', icon: Icons.checklist_outlined),
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
      valueListenable: TasksStore.changeVersion,
      builder: (context, _, __) {
        final daily = TasksStore.dailyGoals;
        final tasks = TasksStore.tasks;
        if (daily.isEmpty && tasks.isEmpty) {
          return AppChromeCentered(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 40,
                  color: AppChrome.accentBronze,
                ),
                AppSpacing.gapMd,
                Text(
                  'No goals or tasks yet',
                  style: context.appTypography.bodyMuted.copyWith(
                    color: AppChrome.onSurfaceMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final progress = TasksStore.progress;
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
              if (progress != null && progress.noMissStreak > 0) ...[
                AppChromeSection(
                  title: 'Streak',
                  goldFrame: true,
                  child: Text(
                    'No-miss streak: ${progress.noMissStreak}',
                    style: context.appTypography.body.copyWith(
                      color: AppChrome.onSurface,
                    ),
                  ),
                ),
                AppSpacing.gapMd,
              ],
              if (daily.isNotEmpty) ...[
                AppChromeSection(
                  title: 'Daily Goals',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _tiles(context, daily),
                  ),
                ),
                AppSpacing.gapMd,
              ],
              if (tasks.isNotEmpty) ...[
                AppChromeSection(
                  title: 'Tasks',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _tiles(context, tasks),
                  ),
                ),
                AppSpacing.gapMd,
              ],
              Text(
                'Completed goals and tasks show under Achievements.',
                style: context.appTypography.bodySmall.copyWith(
                  color: AppChrome.onSurfaceMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _tiles(BuildContext context, List<TaskCatalogEntry> entries) {
    return [
      for (var i = 0; i < entries.length; i++) ...[
        if (i > 0) AppSpacing.gapSm,
        _TaskListTile(
          entry: entries[i],
          progress: TasksStore.progressFor(entries[i].id),
          onTap: () => _openTask(entries[i]),
        ),
      ],
    ];
  }
}

class _TaskListTile extends StatelessWidget {
  const _TaskListTile({
    required this.entry,
    required this.progress,
    required this.onTap,
  });

  final TaskCatalogEntry entry;
  final TaskProgressRow? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final row = progress;
    final isClaimGate = entry.taskType == 'claim_gate';
    final cacheState = isClaimGate
        ? dailyCacheUiState(entry: entry, progress: TasksStore.progress)
        : null;
    final done = row?.completedToday ?? false;
    final miss = row?.missPending ?? false;
    final fraction = row?.progressFraction ?? 0.0;
    final label = cacheState != null
        ? dailyCacheStatusLabel(cacheState)
        : (row?.progressLabel ?? '0 / ${entry.params['min'] ?? 1}');
    final active = done ||
        cacheState == DailyCacheUiState.claimed ||
        cacheState == DailyCacheUiState.ready;
    final radius = BorderRadius.circular(AppSurfaces.exhibitRadius);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppChrome.fieldFill.withValues(alpha: 0.55),
            borderRadius: radius,
            border: Border.all(color: AppChrome.panelBorder),
          ),
          child: Padding(
            padding: AppSpacing.screenPaddingCompact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      done || cacheState == DailyCacheUiState.claimed
                          ? Icons.check_circle
                          : (miss
                              ? Icons.warning_amber_rounded
                              : (cacheState == DailyCacheUiState.ready
                                  ? Icons.card_giftcard_outlined
                                  : Icons.radio_button_unchecked)),
                      color: active
                          ? AppChrome.accentGold
                          : AppChrome.onSurfaceMuted,
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        entry.name,
                        style: context.appTypography.body.copyWith(
                          color: AppChrome.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      label,
                      style: context.appTypography.caption.copyWith(
                        color: AppChrome.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
                if (entry.description.isNotEmpty) ...[
                  AppSpacing.gapXs,
                  Text(
                    entry.description,
                    style: context.appTypography.bodySmall.copyWith(
                      color: AppChrome.onSurfaceMuted,
                    ),
                  ),
                ],
                AppSpacing.gapSm,
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: AppChrome.panelBorder.withValues(alpha: 0.35),
                    color: AppChrome.accentGold,
                  ),
                ),
                if (row != null && row.value > 0) ...[
                  AppSpacing.gapXs,
                  Text(
                    'Streak value: ${row.value}',
                    style: context.appTypography.caption.copyWith(
                      color: AppChrome.onSurfaceMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
