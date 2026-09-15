"""Daily goals module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

INVALID_CATALOG = ErrorSpec(
    "daily_goals/invalid_catalog",
    "Invalid daily goals catalog",
    http_status=500,
)
INVALID_QUERY = ErrorSpec(
    "daily_goals/invalid_query",
    "Invalid daily goals query",
    http_status=400,
)
UNKNOWN_GOAL = ErrorSpec(
    "daily_goals/unknown_goal",
    "Unknown daily goal",
    http_status=404,
)
NOT_MISS_PENDING = ErrorSpec(
    "daily_goals/not_miss_pending",
    "Goal is not awaiting continue or reset",
    http_status=400,
)
INSUFFICIENT_GOLD = ErrorSpec(
    "daily_goals/insufficient_gold",
    "Not enough Gold Arcori to continue",
    http_status=400,
)
GATE_NOT_MET = ErrorSpec(
    "daily_goals/gate_not_met",
    "Required goals are not complete",
    http_status=400,
)
ALREADY_CLAIMED = ErrorSpec(
    "daily_goals/already_claimed",
    "Goal already completed today",
    http_status=400,
)
NOT_CLAIMABLE = ErrorSpec(
    "daily_goals/not_claimable",
    "Goal is not claimable",
    http_status=400,
)
MISS_BLOCKS_PROGRESS = ErrorSpec(
    "daily_goals/miss_blocks_progress",
    "Resolve missed day before progressing",
    http_status=400,
)


def register_daily_goals_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "daily_goals",
        [
            INVALID_CATALOG,
            INVALID_QUERY,
            UNKNOWN_GOAL,
            NOT_MISS_PENDING,
            INSUFFICIENT_GOLD,
            GATE_NOT_MET,
            ALREADY_CLAIMED,
            NOT_CLAIMABLE,
            MISS_BLOCKS_PROGRESS,
        ],
    )
