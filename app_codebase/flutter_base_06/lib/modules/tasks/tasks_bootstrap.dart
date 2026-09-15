import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth/auth_providers.dart';
import '../../utils/dev_logger.dart';
import 'tasks_api.dart';
import 'tasks_store.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Hydrate daily goals + tasks catalog and progress when authenticated.
Future<void> hydrateTasks(WidgetRef ref) async {
  final auth = ref.read(authProvider);
  final token = auth.accessToken?.trim() ?? '';
  if (token.isEmpty) return;

  final api = TasksApiClient();
  final catalogOutcome = await api.fetchCatalog(accessToken: token);
  if (catalogOutcome.isSuccess && catalogOutcome.data != null) {
    TasksStore.applyCatalog(catalogOutcome.data!);
  } else if (LOGGING_SWITCH) {
    customlog(
      'tasks: catalog fetch soft-fail '
      'network=${catalogOutcome.isNetworkError} '
      'code=${catalogOutcome.error?.code}',
    );
  }

  final progressOutcome = await api.fetchProgress(accessToken: token);
  if (progressOutcome.isSuccess && progressOutcome.data != null) {
    TasksStore.applyProgress(progressOutcome.data!);
  } else if (LOGGING_SWITCH) {
    customlog(
      'tasks: progress fetch soft-fail '
      'network=${progressOutcome.isNetworkError} '
      'code=${progressOutcome.error?.code}',
    );
  }

  if (LOGGING_SWITCH) {
    final rev = TasksStore.revision;
    final revShort = rev.length <= 12 ? rev : rev.substring(0, 12);
    customlog(
      'tasks: hydrated daily=${TasksStore.dailyGoals.length} '
      'tasks=${TasksStore.tasks.length} rev=$revShort',
    );
  }
}
