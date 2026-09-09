"""Avari module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

NOT_FOUND = ErrorSpec(
    "avari/not_found",
    "Avari profile not found",
    http_status=404,
)
INVALID_QUERY = ErrorSpec(
    "avari/invalid_query",
    "Invalid avari query",
    http_status=400,
)
KIN_ALREADY_CLAIMED = ErrorSpec(
    "avari/kin_already_claimed",
    "Kin already claimed for this account",
    http_status=409,
)
INVALID_KIN_REGION = ErrorSpec(
    "avari/invalid_kin_region",
    "Invalid Kin region",
    http_status=400,
)
INVALID_KIN_COLOR = ErrorSpec(
    "avari/invalid_kin_color",
    "Invalid Kin Arcori color",
    http_status=400,
)
KIN_CLAIM_FAILED = ErrorSpec(
    "avari/kin_claim_failed",
    "Could not claim Kin",
    http_status=500,
)
INVALID_MATCH_FINALIZE = ErrorSpec(
    "avari/invalid_match_finalize",
    "Invalid match finalize payload",
    http_status=400,
)


def register_avari_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "avari",
        [
            NOT_FOUND,
            INVALID_QUERY,
            KIN_ALREADY_CLAIMED,
            INVALID_KIN_REGION,
            INVALID_KIN_COLOR,
            KIN_CLAIM_FAILED,
            INVALID_MATCH_FINALIZE,
        ],
    )
