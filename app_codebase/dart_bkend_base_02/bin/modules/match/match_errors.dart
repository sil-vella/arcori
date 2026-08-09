/// Module-owned error codes for match hot state.
library;

import '../../core/errors/contracts/register_module_error_contract.dart';
import '../../core/errors/error_spec.dart';

const matchUnauthorized = ErrorSpec(
  'match/unauthorized',
  'User id required',
  401,
);

const matchInvalidRequest = ErrorSpec(
  'match/invalid_request',
  'Invalid match request',
  400,
);

const matchNotFound = ErrorSpec(
  'match/not_found',
  'Match not found',
  404,
);

const matchCatalogFreezeFailed = ErrorSpec(
  'match/catalog_freeze_failed',
  'Failed to freeze catalog designs for match',
  502,
);

const matchForbidden = ErrorSpec(
  'match/forbidden',
  'Not allowed for this match',
  403,
);

const matchInvalidAction = ErrorSpec(
  'match/invalid_action',
  'Unknown or unsupported match action',
  400,
);

const matchNotYourTurn = ErrorSpec(
  'match/not_your_turn',
  'Not your turn to act',
  403,
);

void registerMatchErrors(ModuleErrorRegistrar registrar) {
  registrar.registerModule('match', [
    matchUnauthorized,
    matchInvalidRequest,
    matchNotFound,
    matchCatalogFreezeFailed,
    matchForbidden,
    matchInvalidAction,
    matchNotYourTurn,
  ]);
}
