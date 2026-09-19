import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/errors/api_error.dart';
import '../../../core/errors/error_policy.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../utils/dev_logger.dart';
import '../tasks_api.dart';
import '../tasks_models.dart';
import '../tasks_store.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Daily goal / task detail with claim, continue, and accept-reset actions.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _busy = false;
  String? _actionMessage;
  String? _errorMessage;

  Future<void> _withToken(
    Future<void> Function(String token) run,
  ) async {
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) {
      setState(() => _errorMessage = 'Sign in to manage this task');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
      _actionMessage = null;
    });
    try {
      await run(token);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyOutcomeFailure({
    required ApiError? error,
    required bool isNetworkError,
  }) {
    if (isNetworkError) {
      setState(() => _errorMessage = 'Network error — try again');
      return;
    }
    if (error != null) {
      actionForApiError(error, isWebSocket: false);
      setState(() {
        _errorMessage = error.message.isNotEmpty
            ? error.message
            : 'Something went wrong';
      });
      return;
    }
    setState(() => _errorMessage = 'Something went wrong');
  }

  Future<void> _claim() async {
    await _withToken((token) async {
      final api = TasksApiClient();
      final outcome = await api.claimGoal(
        accessToken: token,
        goalId: widget.taskId,
      );
      if (!mounted) return;
      if (!outcome.isSuccess || outcome.data == null) {
        _applyOutcomeFailure(
          error: outcome.error,
          isNetworkError: outcome.isNetworkError,
        );
        return;
      }
      final result = outcome.data!;
      TasksStore.applyProgress(result.progress);
      final amount = result.reward.amount;
      setState(() {
        _actionMessage = amount > 0
            ? '+$amount Fragments granted'
            : 'Daily Cache claimed';
      });
      if (LOGGING_SWITCH) {
        customlog(
          'tasks: claim ok goal=${widget.taskId} '
          'amount=${result.reward.amount}',
        );
      }
    });
  }

  Future<void> _continueGoal() async {
    await _withToken((token) async {
      final api = TasksApiClient();
      final outcome = await api.continueGoal(
        accessToken: token,
        goalId: widget.taskId,
      );
      if (!mounted) return;
      if (!outcome.isSuccess || outcome.data == null) {
        _applyOutcomeFailure(
          error: outcome.error,
          isNetworkError: outcome.isNetworkError,
        );
        return;
      }
      TasksStore.applyProgress(outcome.data!);
      setState(() => _actionMessage = 'Continued — streak preserved');
    });
  }

  Future<void> _acceptReset() async {
    await _withToken((token) async {
      final api = TasksApiClient();
      final outcome = await api.acceptReset(
        accessToken: token,
        goalId: widget.taskId,
      );
      if (!mounted) return;
      if (!outcome.isSuccess || outcome.data == null) {
        _applyOutcomeFailure(
          error: outcome.error,
          isNetworkError: outcome.isNetworkError,
        );
        return;
      }
      TasksStore.applyProgress(outcome.data!);
      setState(() => _actionMessage = 'Reset accepted');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: TasksStore.changeVersion,
      builder: (context, _, __) {
        final entry = TasksStore.byId(widget.taskId);
        final progress = TasksStore.progressFor(widget.taskId);
        final title = entry?.name.isNotEmpty == true ? entry!.name : widget.taskId;
        final isClaimGate = entry?.taskType == 'claim_gate';
        final cacheState = isClaimGate
            ? dailyCacheUiState(
                entry: entry,
                progress: TasksStore.progress,
              )
            : null;
        final canClaim =
            isClaimGate && cacheState == DailyCacheUiState.ready && !_busy;
        final miss = progress?.missPending == true;
        final continueEnabled =
            miss && (progress?.continueEnabled == true) && !_busy;
        final canReset = miss && !_busy;
        final rewardAmount = entry?.reward.amount ?? 2;

        return ModuleScreenRegistrar(
          appBarItems: [
            AppBarTitle(text: title, icon: Icons.task_alt_outlined),
          ],
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  entry?.description.isNotEmpty == true
                      ? entry!.description
                      : 'Task details.',
                  style: context.appTypography.body,
                ),
                AppSpacing.gapMd,
                if (entry != null) ...[
                  Text(
                    'Section: ${entry.isDailyGoal ? 'Daily Goal' : 'Task'}',
                    style: context.appTypography.bodySmall,
                  ),
                  AppSpacing.gapXs,
                  Text(
                    'Type: ${entry.taskType}',
                    style: context.appTypography.bodySmall,
                  ),
                ],
                if (progress != null) ...[
                  AppSpacing.gapMd,
                  Text(
                    'Progress: ${progress.progressLabel}',
                    style: context.appTypography.body,
                  ),
                  AppSpacing.gapXs,
                  Text(
                    'Value: ${progress.value}',
                    style: context.appTypography.bodySmall,
                  ),
                ],
                if (cacheState != null) ...[
                  AppSpacing.gapMd,
                  Text(
                    'Daily Cache: ${dailyCacheStatusLabel(cacheState)}',
                    style: context.appTypography.body,
                  ),
                  if (cacheState == DailyCacheUiState.locked)
                    Text(
                      'Complete featured missions first.',
                      style: context.appTypography.bodySmall,
                    ),
                ],
                if (_actionMessage != null) ...[
                  AppSpacing.gapMd,
                  Text(
                    _actionMessage!,
                    style: context.appTypography.body.copyWith(
                      color: context.appColorScheme.primary,
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  AppSpacing.gapMd,
                  Text(
                    _errorMessage!,
                    style: context.appTypography.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const Spacer(),
                if (isClaimGate) ...[
                  FilledButton(
                    onPressed: canClaim ? () => _claim() : null,
                    child: Text(
                      cacheState == DailyCacheUiState.claimed
                          ? 'Claimed'
                          : 'Claim (+$rewardAmount Fragments)',
                    ),
                  ),
                  AppSpacing.gapSm,
                ],
                if (miss) ...[
                  FilledButton(
                    onPressed: continueEnabled ? () => _continueGoal() : null,
                    child: Text(
                      progress?.continueCost != null &&
                              progress!.continueCost > 0
                          ? 'Continue (${progress.continueCost} Gold Arcori)'
                          : 'Continue',
                    ),
                  ),
                  AppSpacing.gapSm,
                  OutlinedButton(
                    onPressed: canReset ? () => _acceptReset() : null,
                    child: const Text('Accept reset'),
                  ),
                ],
                if (_busy) ...[
                  AppSpacing.gapMd,
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
