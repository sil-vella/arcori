"""Closed sets for daily goal task_type, cadence, and post actions."""

from __future__ import annotations

TASK_TYPE_MATCHES_COMPLETED = "matches_completed"
TASK_TYPE_FLIPS_COMPLETED = "flips_completed"
TASK_TYPE_WINS_COMPLETED = "wins_completed"
TASK_TYPE_LOGIN = "login"
TASK_TYPE_CLAIM_GATE = "claim_gate"

TASK_TYPES = frozenset(
    {
        TASK_TYPE_MATCHES_COMPLETED,
        TASK_TYPE_FLIPS_COMPLETED,
        TASK_TYPE_WINS_COMPLETED,
        TASK_TYPE_LOGIN,
        TASK_TYPE_CLAIM_GATE,
    }
)

CADENCE_DAILY = "daily"
CADENCES = frozenset({CADENCE_DAILY})

SECTION_DAILY_GOALS = "daily_goals"
SECTION_TASKS = "tasks"
SECTIONS = frozenset({SECTION_DAILY_GOALS, SECTION_TASKS})

POST_ACTION_NONE = "none"
POST_ACTION_MOVE_TO_SCREEN = "move_to_screen"
POST_ACTION_OPEN_PATH = "open_path"

POST_COMPLETE_ACTION_TYPES = frozenset(
    {
        POST_ACTION_NONE,
        POST_ACTION_MOVE_TO_SCREEN,
        POST_ACTION_OPEN_PATH,
    }
)

VALUE_KIND_STREAK = "streak"
ON_MISS_RESET_TO_ZERO = "reset_to_zero"

CONTINUE_CURRENCY_GOLD_ARCORI = "gold_arcori"
