"""Legacy module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

INVALID_QUERY = ErrorSpec(
    "legacy/invalid_query",
    "Invalid legacy request",
    http_status=400,
)
NOT_ELIGIBLE = ErrorSpec(
    "legacy/not_eligible",
    "Not eligible to preserve this generation",
    http_status=403,
)
OFFER_EXPIRED = ErrorSpec(
    "legacy/offer_expired",
    "Preservation offer expired",
    http_status=409,
)
ALREADY_CLOSED = ErrorSpec(
    "legacy/already_closed",
    "This generation is already closed",
    http_status=409,
)
NOT_LEADER = ErrorSpec(
    "legacy/not_leader",
    "Only the current 30-day leader may preserve",
    http_status=403,
)
INVALID_FULFILL = ErrorSpec(
    "legacy/invalid_fulfill",
    "Invalid legacy fulfill payload",
    http_status=400,
)
INTENT_NOT_FOUND = ErrorSpec(
    "legacy/intent_not_found",
    "Preserve checkout intent not found",
    http_status=404,
)
PROCESSING = ErrorSpec(
    "legacy/processing",
    "Mint fulfillment still processing",
    http_status=409,
)


def register_legacy_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "legacy",
        [
            INVALID_QUERY,
            NOT_ELIGIBLE,
            OFFER_EXPIRED,
            ALREADY_CLOSED,
            NOT_LEADER,
            INVALID_FULFILL,
            INTENT_NOT_FOUND,
            PROCESSING,
        ],
    )
