/// Match action pack contract — core SSOT + optional type/subtype packs.
library;

import 'match_models.dart';
import 'match_store.dart';

typedef MatchActionHandler = MatchSnapshot Function({
  required MatchStore store,
  required MatchSnapshot current,
  required String actorUserId,
  required Map<String, dynamic> payload,
});

abstract class MatchActionPack {
  /// Action names this pack owns (e.g. `slam`).
  Set<String> get actionNames;

  MatchActionHandler? handlerFor(String action);
}
