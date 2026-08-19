"""Friend match invite module error catalog."""

from core.errors.contracts.register_module_error_contract import (
    ModuleErrorRegistrar,
)
from core.errors.error_spec import ErrorSpec


friend_match_inviteUnauthorized = ErrorSpec(
    "friend_match_invite/unauthorized",
    "Unauthorized",
    http_status=401,
)

friend_match_inviteInvalidRequest = ErrorSpec(
    "friend_match_invite/invalid_request",
    "Invalid invite request",
    http_status=400,
)

friend_match_inviteNotFound = ErrorSpec(
    "friend_match_invite/invite_not_found",
    "Invite not found",
    http_status=404,
)

friend_match_inviteForbidden = ErrorSpec(
    "friend_match_invite/invite_forbidden",
    "You are not allowed to respond to this invite",
    http_status=403,
)

friend_match_inviteNotPending = ErrorSpec(
    "friend_match_invite/invite_not_pending",
    "Invite has already been accepted/declined",
    http_status=409,
)


def register_friend_match_invite_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "friend_match_invite",
        [
            friend_match_inviteUnauthorized,
            friend_match_inviteInvalidRequest,
            friend_match_inviteNotFound,
            friend_match_inviteForbidden,
            friend_match_inviteNotPending,
        ],
    )

