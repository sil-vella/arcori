import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/modal/modal.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/navigation/app_paths.dart';
import '../../core/navigation/app_router.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/state/auth/auth_state.dart';
import '../../core/theme/theme.dart';
import '../../utils/dev_logger.dart';
import 'daily_missions_nudge_prefs.dart';
import 'tasks_api.dart';
import 'tasks_models.dart';
import 'tasks_store.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Soft once-per-day returning nudge → /tasks after auth bootstrap.
class DailyMissionsNudgeHost extends ConsumerStatefulWidget {
  const DailyMissionsNudgeHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DailyMissionsNudgeHost> createState() =>
      _DailyMissionsNudgeHostState();
}

class _DailyMissionsNudgeHostState
    extends ConsumerState<DailyMissionsNudgeHost> {
  bool _attempted = false;
  final _prefs = DailyMissionsNudgePrefs();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryStart());
  }

  void _tryStart() {
    if (_attempted || !mounted) return;
    final auth = ref.read(authProvider);
    if (auth.isBootstrapping || !auth.isAuthenticated) return;
    _attempted = true;
    unawaited(_maybeNudge());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      final becameReady = previous?.isBootstrapping == true &&
          !next.isBootstrapping &&
          next.isAuthenticated;
      if (!becameReady) return;
      if (_attempted) return;
      _attempted = true;
      unawaited(_maybeNudge());
    });

    return widget.child;
  }

  Future<void> _maybeNudge() async {
    // Let Home / NotificationHost settle first.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) return;

    final api = TasksApiClient();
    final catalogOutcome = await api.fetchCatalog(accessToken: token);
    if (catalogOutcome.isSuccess && catalogOutcome.data != null) {
      TasksStore.applyCatalog(catalogOutcome.data!);
    }
    final progressOutcome = await api.fetchProgress(accessToken: token);
    if (!progressOutcome.isSuccess || progressOutcome.data == null) {
      if (LOGGING_SWITCH) {
        customlog(
          'dailyNudge: progress soft-fail '
          'network=${progressOutcome.isNetworkError}',
        );
      }
      return;
    }
    final progress = progressOutcome.data!;
    TasksStore.applyProgress(progress);

    final dayKey = progress.dayKey.trim();
    if (dayKey.isEmpty) return;
    final shown = (await _prefs.readShownDayKey())?.trim() ?? '';
    if (shown == dayKey) {
      if (LOGGING_SWITCH) {
        customlog('dailyNudge: already shown day=$dayKey');
      }
      return;
    }

    if (!_shouldNudge(progress)) {
      if (LOGGING_SWITCH) {
        customlog('dailyNudge: skip — daily complete day=$dayKey');
      }
      return;
    }

    await _prefs.writeShownDayKey(dayKey);

    final rootCtx = appRootNavigatorKey.currentContext;
    if (rootCtx == null || !rootCtx.mounted) return;

    if (LOGGING_SWITCH) {
      customlog('dailyNudge: show modal day=$dayKey');
    }

    await AppModal.showCenteredShell<void>(
      rootCtx,
      title: 'Daily Missions',
      barrierDismissible: true,
      showCloseButton: true,
      child: const _DailyMissionsNudgeBody(),
    );
  }

  bool _shouldNudge(TasksProgressSnapshot progress) {
    for (final row in progress.goals) {
      if (row.featured && !row.completedToday) return true;
    }
    final cacheEntry = TasksStore.byId('daily_mystery_box');
    final cacheRow = progress.byGoalId('daily_mystery_box');
    if (cacheRow == null || !cacheRow.completedToday) {
      // Unclaimed cache (locked or ready) — soft nudge to Tasks.
      if (cacheEntry?.taskType == 'claim_gate' || cacheRow != null) {
        return true;
      }
    }
    return false;
  }
}

class _DailyMissionsNudgeBody extends StatelessWidget {
  const _DailyMissionsNudgeBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Featured missions and Daily Cache are waiting on Tasks.',
          style: context.appTypography.body,
        ),
        AppSpacing.gapLg,
        FilledButton(
          onPressed: () {
            AppModal.dismiss(context);
            final rootCtx = appRootNavigatorKey.currentContext;
            if (rootCtx != null && rootCtx.mounted) {
              Nav.go(rootCtx, AppPaths.tasks);
            }
          },
          child: const Text('Open'),
        ),
        AppSpacing.gapSm,
        OutlinedButton(
          onPressed: () => AppModal.dismiss(context),
          child: const Text('Later'),
        ),
      ],
    );
  }
}
