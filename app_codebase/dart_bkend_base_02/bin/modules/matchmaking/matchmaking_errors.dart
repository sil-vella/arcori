/// Matchmaking module errors.
library;

import '../../core/errors/contracts/register_module_error_contract.dart';
import '../../core/errors/error_spec.dart';

const matchmakingUnauthorized = ErrorSpec(
  'matchmaking/unauthorized',
  'User id required',
  401,
);

const matchmakingInvalidRequest = ErrorSpec(
  'matchmaking/invalid_request',
  'Invalid matchmaking request',
  400,
);

const matchmakingNotInLobby = ErrorSpec(
  'matchmaking/not_in_lobby',
  'Not in a lobby',
  404,
);

const matchmakingAiUnavailable = ErrorSpec(
  'matchmaking/ai_unavailable',
  'Not enough AI players available',
  503,
);

const matchmakingPromoteFailed = ErrorSpec(
  'matchmaking/promote_failed',
  'Failed to promote lobby to match',
  502,
);

const matchmakingInviteNotFound = ErrorSpec(
  'matchmaking/invite_not_found',
  'Invite lobby not found (invite may be expired or not created yet)',
  404,
);

const matchmakingInviteNeedsMoreHumans = ErrorSpec(
  'matchmaking/invite_needs_more_humans',
  'Invite requires the invited human(s); AI fill is disabled',
  409,
);

void registerMatchmakingErrors(ModuleErrorRegistrar registrar) {
  registrar.registerModule('matchmaking', [
    matchmakingUnauthorized,
    matchmakingInvalidRequest,
    matchmakingNotInLobby,
    matchmakingAiUnavailable,
    matchmakingPromoteFailed,
    matchmakingInviteNotFound,
    matchmakingInviteNeedsMoreHumans,
  ]);
}
