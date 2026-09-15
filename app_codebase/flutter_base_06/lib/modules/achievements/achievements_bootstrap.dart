import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth/auth_providers.dart';
import '../../utils/dev_logger.dart';
import 'achievements_api.dart';
import 'achievements_catalog_store.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Hydrate catalog + unlocked ids when authenticated. Refetch if revision differs.
Future<void> hydrateAchievementsCatalog(WidgetRef ref) async {
  final auth = ref.read(authProvider);
  final token = auth.accessToken?.trim() ?? '';
  if (token.isEmpty) return;

  final api = AchievementsApiClient();
  final catalogOutcome = await api.fetchCatalog(accessToken: token);
  if (!catalogOutcome.isSuccess || catalogOutcome.data == null) {
    if (LOGGING_SWITCH) {
      customlog(
        'achievements: catalog fetch soft-fail '
        'network=${catalogOutcome.isNetworkError} '
        'code=${catalogOutcome.error?.code}',
      );
    }
    return;
  }
  final catalog = catalogOutcome.data!;
  if (catalog.revision.isNotEmpty &&
      catalog.revision == AchievementsCatalogStore.revision &&
      AchievementsCatalogStore.hasDocument) {
    // Still refresh unlocked ids.
  } else {
    AchievementsCatalogStore.applyCatalog(catalog);
  }

  final unlockedOutcome = await api.fetchUnlockedIds(accessToken: token);
  if (unlockedOutcome.isSuccess && unlockedOutcome.data != null) {
    AchievementsCatalogStore.applyUnlockedIds(unlockedOutcome.data!);
  }
  if (LOGGING_SWITCH) {
    final rev = AchievementsCatalogStore.revision;
    final revShort = rev.length <= 12 ? rev : rev.substring(0, 12);
    customlog(
      'achievements: hydrated count=${AchievementsCatalogStore.all.length} '
      'unlocked=${AchievementsCatalogStore.unlockedIds.length} '
      'rev=$revShort',
    );
  }
}
