"""Market module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

INVALID_QUERY = ErrorSpec(
    "market/invalid_query",
    "Invalid market request",
    http_status=400,
)
NOT_FOR_SALE = ErrorSpec(
    "market/not_for_sale",
    "That slammer is not available in the Market",
    http_status=404,
)
ALREADY_OWNED = ErrorSpec(
    "market/already_owned",
    "You already own this slammer",
    http_status=409,
)
NOT_OWNED = ErrorSpec(
    "market/not_owned",
    "You do not own this slammer",
    http_status=404,
)
PERMANENT_NO_RECHARGE = ErrorSpec(
    "market/permanent_no_recharge",
    "Permanent slammers do not need a charge top-up",
    http_status=400,
)
INSUFFICIENT_GOLD = ErrorSpec(
    "market/insufficient_gold",
    "Not enough Gold Arcori",
    http_status=402,
)


def register_market_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "market",
        [
            INVALID_QUERY,
            NOT_FOR_SALE,
            ALREADY_OWNED,
            NOT_OWNED,
            PERMANENT_NO_RECHARGE,
            INSUFFICIENT_GOLD,
        ],
    )
