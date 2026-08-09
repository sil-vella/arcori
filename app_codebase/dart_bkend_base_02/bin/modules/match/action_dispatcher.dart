/// Routes `match/action` to core pack first, then type/subtype pack.
library;

import '../../core/errors/app_error.dart';
import 'action_pack.dart';
import 'core_action_pack.dart';
import 'match_errors.dart';
import 'match_models.dart';
import 'match_store.dart';
import 'type_subtype_pack_registry.dart';

class ActionDispatcher {
  ActionDispatcher({
    MatchStore? store,
    MatchActionPack? core,
    TypeSubtypePackRegistry? packs,
  })  : _store = store ?? matchStore,
        _core = core ?? coreActionPack,
        _packs = packs ?? typeSubtypePackRegistry;

  final MatchStore _store;
  final MatchActionPack _core;
  final TypeSubtypePackRegistry _packs;

  MatchSnapshot dispatch({
    required String matchId,
    required String actorUserId,
    required Map<String, dynamic> payload,
  }) {
    final action = payload['action']?.toString().trim() ?? '';
    if (action.isEmpty) {
      throw AppError(matchInvalidAction, message: 'action required');
    }
    final current = _store.getSnapshot(matchId);
    if (current == null) {
      throw AppError(matchNotFound);
    }

    MatchActionHandler? handler = _core.handlerFor(action);
    if (handler == null) {
      final pack = _packs.packFor(current.matchType);
      handler = pack?.handlerFor(action);
    }
    if (handler == null) {
      throw AppError(matchInvalidAction, message: 'Unsupported action: $action');
    }

    return handler(
      store: _store,
      current: current,
      actorUserId: actorUserId,
      payload: payload,
    );
  }
}

final actionDispatcher = ActionDispatcher();
