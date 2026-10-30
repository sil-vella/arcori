"""Store module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

INVALID_QUERY = ErrorSpec(
    "store/invalid_query",
    "Invalid store request",
    http_status=400,
)
UNKNOWN_PRODUCT = ErrorSpec(
    "store/unknown_product",
    "Unknown fragment pack",
    http_status=400,
)
NOT_CONFIGURED = ErrorSpec(
    "store/not_configured",
    "Store verification is not configured",
    http_status=503,
)
INVALID_RECEIPT = ErrorSpec(
    "store/invalid_receipt",
    "The store could not confirm this purchase",
    http_status=400,
)
VERIFY_FAILED = ErrorSpec(
    "store/verify_failed",
    "Store verification failed",
    http_status=502,
)
RECEIPT_OWNED = ErrorSpec(
    "store/receipt_owned",
    "This purchase belongs to another account",
    http_status=403,
)


def register_store_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "store",
        [
            INVALID_QUERY,
            UNKNOWN_PRODUCT,
            NOT_CONFIGURED,
            INVALID_RECEIPT,
            VERIFY_FAILED,
            RECEIPT_OWNED,
        ],
    )
