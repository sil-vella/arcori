"""Daily goals business logic — catalog, rollover, continue, claim, match apply."""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Any

from sqlalchemy.orm import Session

from core.errors.app_error import AppError
from core.utils.dev_logger import customlog
from core.utils.media_fields import media_for_client
from models.avari_profile import AvariProfile
from modules.avari.gold_economy import apply_fragment_delta, normalize_wallet
from modules.daily_goals import daily_goals_repository as repo
from modules.daily_goals.daily_goals_errors import (
    ALREADY_CLAIMED,
    GATE_NOT_MET,
    INSUFFICIENT_GOLD,
    INVALID_QUERY,
    MISS_BLOCKS_PROGRESS,
    NOT_CLAIMABLE,
    NOT_MISS_PENDING,
    UNKNOWN_GOAL,
)
from modules.daily_goals.daily_goals_loader import (
    catalog_revision,
    featured_goal_ids,
    goal_by_id,
    list_goals,
    load_daily_goals_document,
)
from modules.daily_goals.daily_goals_notifications import notify_daily_completions
from modules.daily_goals.daily_goals_types import (
    TASK_TYPE_CLAIM_GATE,
    TASK_TYPE_FLIPS_COMPLETED,
    TASK_TYPE_LOGIN,
    TASK_TYPE_MATCHES_COMPLETED,
    TASK_TYPE_WINS_COMPLETED,
)

LOGGING_SWITCH = True


def utc_day_key(now: datetime | None = None) -> str:
    dt = now or datetime.now(timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).date().isoformat()


def _prev_day_key(day_key: str) -> str:
    d = date.fromisoformat(day_key)
    return (d - timedelta(days=1)).isoformat()


def _camel_post_action(action: dict[str, Any]) -> dict[str, Any]:
    atype = str(action.get("type") or "none")
    out: dict[str, Any] = {"type": atype}
    if "screen" in action:
        out["screen"] = action["screen"]
    if "to_path" in action:
        out["toPath"] = action["to_path"]
    if "cta_label" in action:
        out["ctaLabel"] = action["cta_label"]
    return out


def client_goal_row(entry: dict[str, Any]) -> dict[str, Any]:
    action = entry.get("post_complete_action")
    if not isinstance(action, dict):
        action = {"type": "none"}
    value = entry.get("value") if isinstance(entry.get("value"), dict) else {}
    cont = entry.get("continue") if isinstance(entry.get("continue"), dict) else {}
    reward = entry.get("reward") if isinstance(entry.get("reward"), dict) else {}
    media = entry.get("media") if isinstance(entry.get("media"), dict) else {}
    return {
        "id": entry.get("id"),
        "name": entry.get("name"),
        "description": entry.get("description") or "",
        "cadence": entry.get("cadence"),
        "featured": bool(entry.get("featured")),
        "section": entry.get("section") or "tasks",
        "taskType": entry.get("task_type"),
        "params": entry.get("params") or {},
        "value": {
            "kind": value.get("kind"),
            "onCompleteDelta": value.get("on_complete_delta"),
            "onMiss": value.get("on_miss"),
        },
        "continue": {
            "enabled": bool(cont.get("enabled")),
            "currency": cont.get("currency") or "gold_arcori",
            "cost": int(cont.get("cost") or 0),
        },
        "reward": {
            "kind": reward.get("kind") or "deferred",
            **(
                {"placeholder": True}
                if reward.get("placeholder")
                else {}
            ),
            **(
                {"tableId": reward.get("table_id")}
                if "table_id" in reward
                else {}
            ),
            **(
                {"amount": int(reward.get("amount"))}
                if reward.get("amount") is not None
                else {}
            ),
        },
        "media": media_for_client(media),
        "postCompleteAction": _camel_post_action(action),
    }


def get_catalog_payload() -> dict[str, Any]:
    doc, revision = load_daily_goals_document()
    rows = [client_goal_row(e) for e in (doc.get("goals") or [])]
    return {
        "revision": revision,
        "schemaVersion": int(doc.get("schema_version") or 1),
        "dayBoundary": doc.get("day_boundary") or "utc",
        "goals": rows,
    }


def _target_min(goal: dict[str, Any]) -> int:
    params = goal.get("params") or {}
    try:
        return max(1, int(params.get("min", 1)))
    except (TypeError, ValueError):
        return 1


def _apply_rollover(row: Any, goal: dict[str, Any], today: str) -> bool:
    """Advance row into ``today``. Returns True if a miss was newly opened."""
    if row.day_key == today:
        return False
    opened_miss = False
    prev = row.day_key
    was_completed = bool(row.completed_today)
    cont = goal.get("continue") if isinstance(goal.get("continue"), dict) else {}
    continue_enabled = bool(cont.get("enabled"))

    if prev is None:
        row.day_key = today
        row.progress_today = 0
        row.completed_today = False
        row.miss_pending = False
        return False

    if was_completed:
        row.day_key = today
        row.progress_today = 0
        row.completed_today = False
        row.miss_pending = False
        return False

    # Incomplete previous window(s).
    if continue_enabled:
        row.day_key = today
        row.progress_today = 0
        row.completed_today = False
        row.miss_pending = True
        opened_miss = True
    else:
        row.value = 0
        row.day_key = today
        row.progress_today = 0
        row.completed_today = False
        row.miss_pending = False
    return opened_miss


def _mark_complete(row: Any, goal: dict[str, Any], today: str) -> None:
    if row.completed_today:
        return
    value_cfg = goal.get("value") if isinstance(goal.get("value"), dict) else {}
    try:
        delta = max(0, int(value_cfg.get("on_complete_delta", 1)))
    except (TypeError, ValueError):
        delta = 1
    row.completed_today = True
    row.progress_today = max(int(row.progress_today), _target_min(goal))
    row.value = int(row.value) + delta
    row.last_completed_day_key = today
    row.miss_pending = False


def _sync_no_miss_streak(session: Session, avari: AvariProfile, today: str) -> int:
    featured = featured_goal_ids()
    if not featured:
        return int(getattr(avari, "daily_no_miss_streak", 0) or 0)
    all_done = True
    for gid in featured:
        row = repo.get_progress_row(session, avari.user_id, gid)
        if row is None or not bool(row.completed_today) or row.day_key != today:
            all_done = False
            break
    if not all_done:
        return int(getattr(avari, "daily_no_miss_streak", 0) or 0)

    # All featured complete today — bump streak if yesterday was also full, else 1.
    yesterday = _prev_day_key(today)
    yesterday_full = True
    for gid in featured:
        row = repo.get_progress_row(session, avari.user_id, gid)
        if row is None or str(row.last_completed_day_key or "") not in {today, yesterday}:
            # last_completed is today for all (just finished); check prior streak via profile
            yesterday_full = False
            break
        # If any featured last completed before yesterday, break streak base.
        last = str(row.last_completed_day_key or "")
        if last != today and last != yesterday:
            yesterday_full = False
            break

    # Simpler rule: if every featured last_completed_day_key == today AND
    # previous streak day was consecutive — use profile: if any featured had
    # last_completed == yesterday before today's complete, streak continues.
    # After completing today, all last_completed == today. Use: if prior streak
    # value > 0 and we completed yesterday's set (stored on profile via last
    # login reward day) — keep it simple:
    prior = int(getattr(avari, "daily_no_miss_streak", 0) or 0)
    # Detect first completion of the set today: if any featured has
    # last_completed != today before mark — callers call after marks.
    # Here assume just completed the last featured today.
    # Continue streak if yesterday all had last_completed_day_key == yesterday
    # before today's updates — we only see today now. Heuristic: if prior > 0
    # and daily_last_login_reward_at / use: check if progress rows' values
    # imply consecutive — if prior streak and day_key rolled from completed
    # yesterday (value already high). Use: yesterday_full via value of
    # checking that before today each featured was completed yesterday:
    # We stored last_completed as today for all — look at whether prior was
    # already incremented today (idempotent).
    last_reward = getattr(avari, "daily_last_login_reward_at", None)
    already_today = False
    if isinstance(last_reward, datetime):
        already_today = last_reward.astimezone(timezone.utc).date().isoformat() == today

    if already_today:
        return prior

    # Did we complete all featured yesterday? Infer from last_completed being
    # today for all (just set) and prior streak: if each row's value >= 1 and
    # we check yesterday completion by seeing last_completed was yesterday
    # for incomplete... Too late. Store marker on profile when set completes.
    new_streak = 1
    # If profile's last daily reward day was yesterday, continue.
    if isinstance(last_reward, datetime):
        last_day = last_reward.astimezone(timezone.utc).date().isoformat()
        if last_day == yesterday:
            new_streak = prior + 1 if prior > 0 else 1
        elif last_day == today:
            return prior
    avari.daily_no_miss_streak = new_streak
    avari.daily_last_login_reward_at = datetime.now(timezone.utc)
    return new_streak


def _progress_client_row(goal: dict[str, Any], row: Any) -> dict[str, Any]:
    target = _target_min(goal) if goal.get("task_type") != TASK_TYPE_CLAIM_GATE else 1
    cont = goal.get("continue") if isinstance(goal.get("continue"), dict) else {}
    return {
        "goalId": goal.get("id"),
        "name": goal.get("name") or goal.get("id"),
        "value": int(row.value or 0),
        "dayKey": row.day_key,
        "progressToday": int(row.progress_today or 0),
        "target": target,
        "completedToday": bool(row.completed_today),
        "missPending": bool(row.miss_pending),
        "continueEnabled": bool(cont.get("enabled")),
        "continueCost": int(cont.get("cost") or 0),
        "lastCompletedDayKey": row.last_completed_day_key,
        "taskType": goal.get("task_type"),
        "featured": bool(goal.get("featured")),
        "rewardKind": (goal.get("reward") or {}).get("kind")
        if isinstance(goal.get("reward"), dict)
        else "deferred",
    }


def ensure_all_rollover(
    session: Session, *, user_id: str, today: str | None = None
) -> list[str]:
    """Ensure rows + rollover for every catalog goal. Returns goal ids that opened miss."""
    day = today or utc_day_key()
    opened: list[str] = []
    for goal in list_goals():
        gid = str(goal.get("id") or "")
        row = repo.upsert_progress_row(session, user_id=user_id, goal_id=gid)
        if _apply_rollover(row, goal, day):
            opened.append(gid)
            # Featured miss breaks no-miss streak immediately when miss opens.
            if goal.get("featured"):
                # Will reset on accept/auto; opening miss already means yesterday failed.
                pass
    return opened


def _add_progress(
    session: Session,
    *,
    user_id: str,
    goal: dict[str, Any],
    amount: int,
    today: str,
) -> bool:
    """Increment progress; complete if threshold met. Returns True if newly completed."""
    if amount <= 0:
        return False
    gid = str(goal.get("id") or "")
    row = repo.upsert_progress_row(session, user_id=user_id, goal_id=gid)
    _apply_rollover(row, goal, today)
    if row.miss_pending:
        return False
    if row.completed_today:
        return False
    if goal.get("task_type") == TASK_TYPE_CLAIM_GATE:
        return False
    row.progress_today = int(row.progress_today or 0) + int(amount)
    if row.progress_today >= _target_min(goal):
        _mark_complete(row, goal, today)
        return True
    return False


def apply_match_event(
    session: Session,
    *,
    user_id: str,
    avari: AvariProfile,
    flips: int,
    won: bool,
) -> dict[str, Any]:
    """Advance match-driven daily goals after online finalize."""
    today = utc_day_key()
    ensure_all_rollover(session, user_id=user_id, today=today)
    changed: list[str] = []
    for goal in list_goals():
        ttype = goal.get("task_type")
        newly = False
        if ttype == TASK_TYPE_MATCHES_COMPLETED:
            newly = _add_progress(
                session, user_id=user_id, goal=goal, amount=1, today=today
            )
        elif ttype == TASK_TYPE_FLIPS_COMPLETED:
            newly = _add_progress(
                session, user_id=user_id, goal=goal, amount=max(0, int(flips)), today=today
            )
        elif ttype == TASK_TYPE_WINS_COMPLETED and won:
            newly = _add_progress(
                session, user_id=user_id, goal=goal, amount=1, today=today
            )
        if newly:
            changed.append(str(goal.get("id")))
    no_miss = _sync_no_miss_streak(session, avari, today)
    session.flush()
    completed_rows = [
        client_goal_row(goal_by_id(gid))
        for gid in changed
        if goal_by_id(gid) is not None
    ]
    payload = build_progress_payload(
        session, user_id=user_id, avari=avari, changed_goal_ids=changed, no_miss=no_miss
    )
    payload["goalsCompleted"] = completed_rows
    return payload


def apply_login_goals(
    session: Session, *, user_id: str, avari: AvariProfile
) -> list[str]:
    today = utc_day_key()
    ensure_all_rollover(session, user_id=user_id, today=today)
    changed: list[str] = []
    for goal in list_goals():
        if goal.get("task_type") != TASK_TYPE_LOGIN:
            continue
        if _add_progress(session, user_id=user_id, goal=goal, amount=1, today=today):
            changed.append(str(goal.get("id")))
    _sync_no_miss_streak(session, avari, today)
    return changed


def build_progress_payload(
    session: Session,
    *,
    user_id: str,
    avari: AvariProfile | None = None,
    changed_goal_ids: list[str] | None = None,
    no_miss: int | None = None,
) -> dict[str, Any]:
    today = utc_day_key()
    ensure_all_rollover(session, user_id=user_id, today=today)
    goals_out: list[dict[str, Any]] = []
    for goal in list_goals():
        gid = str(goal.get("id") or "")
        row = repo.upsert_progress_row(session, user_id=user_id, goal_id=gid)
        _apply_rollover(row, goal, today)
        goals_out.append(_progress_client_row(goal, row))
    gold_a = int(avari.gold_arcori) if avari is not None else 0
    gold_f = int(avari.gold_fragments) if avari is not None else 0
    if avari is not None:
        gold_a, gold_f = normalize_wallet(gold_a, gold_f)
    streak = (
        int(no_miss)
        if no_miss is not None
        else int(getattr(avari, "daily_no_miss_streak", 0) or 0)
        if avari is not None
        else 0
    )
    return {
        "revision": catalog_revision(),
        "dayKey": today,
        "dayBoundary": "utc",
        "noMissStreak": streak,
        "goldArcori": gold_a,
        "goldFragments": gold_f,
        "goals": goals_out,
        "changedGoalIds": list(changed_goal_ids or []),
    }


def get_progress_payload(session: Session, user_id: str, avari: AvariProfile) -> dict[str, Any]:
    apply_login_goals(session, user_id=user_id, avari=avari)
    session.flush()
    return build_progress_payload(session, user_id=user_id, avari=avari)


def continue_goal(
    session: Session, *, user_id: str, avari: AvariProfile, goal_id: str
) -> dict[str, Any]:
    gid = (goal_id or "").strip()
    goal = goal_by_id(gid)
    if goal is None:
        raise AppError(UNKNOWN_GOAL)
    today = utc_day_key()
    row = repo.upsert_progress_row(session, user_id=user_id, goal_id=gid)
    _apply_rollover(row, goal, today)
    if not row.miss_pending:
        raise AppError(NOT_MISS_PENDING)
    cont = goal.get("continue") if isinstance(goal.get("continue"), dict) else {}
    if not cont.get("enabled"):
        raise AppError(NOT_MISS_PENDING, message="Continue is not enabled for this goal")
    cost = max(0, int(cont.get("cost") or 0))
    arcori, frags = normalize_wallet(int(avari.gold_arcori), int(avari.gold_fragments))
    if arcori < cost:
        raise AppError(INSUFFICIENT_GOLD)
    avari.gold_arcori = arcori - cost
    avari.gold_fragments = frags
    row.miss_pending = False
    # Preserve value; allow today's progress.
    session.flush()
    if LOGGING_SWITCH:
        customlog(f"daily_goals: continue user={user_id} goal={gid} cost={cost}")
    return build_progress_payload(
        session, user_id=user_id, avari=avari, changed_goal_ids=[gid]
    )


def accept_reset(
    session: Session, *, user_id: str, avari: AvariProfile, goal_id: str
) -> dict[str, Any]:
    gid = (goal_id or "").strip()
    goal = goal_by_id(gid)
    if goal is None:
        raise AppError(UNKNOWN_GOAL)
    today = utc_day_key()
    row = repo.upsert_progress_row(session, user_id=user_id, goal_id=gid)
    _apply_rollover(row, goal, today)
    if not row.miss_pending:
        raise AppError(NOT_MISS_PENDING)
    row.value = 0
    row.miss_pending = False
    row.progress_today = 0
    row.completed_today = False
    if goal.get("featured"):
        avari.daily_no_miss_streak = 0
    session.flush()
    if LOGGING_SWITCH:
        customlog(f"daily_goals: accept_reset user={user_id} goal={gid}")
    return build_progress_payload(
        session, user_id=user_id, avari=avari, changed_goal_ids=[gid]
    )


def claim_goal(
    session: Session, *, user_id: str, avari: AvariProfile, goal_id: str
) -> dict[str, Any]:
    gid = (goal_id or "").strip()
    goal = goal_by_id(gid)
    if goal is None:
        raise AppError(UNKNOWN_GOAL)
    if goal.get("task_type") != TASK_TYPE_CLAIM_GATE:
        raise AppError(NOT_CLAIMABLE)
    today = utc_day_key()
    ensure_all_rollover(session, user_id=user_id, today=today)
    row = repo.upsert_progress_row(session, user_id=user_id, goal_id=gid)
    _apply_rollover(row, goal, today)
    if row.miss_pending:
        raise AppError(MISS_BLOCKS_PROGRESS)
    if row.completed_today:
        raise AppError(ALREADY_CLAIMED)

    params = goal.get("params") or {}
    required = params.get("requires_goal_ids") or []
    if not isinstance(required, list):
        required = []
    for req_id in required:
        rid = str(req_id).strip()
        if not rid:
            continue
        req_row = repo.get_progress_row(session, user_id, rid)
        if (
            req_row is None
            or not bool(req_row.completed_today)
            or req_row.day_key != today
        ):
            raise AppError(GATE_NOT_MET)

    _mark_complete(row, goal, today)
    no_miss = _sync_no_miss_streak(session, avari, today)

    reward = goal.get("reward") if isinstance(goal.get("reward"), dict) else {}
    kind = str(reward.get("kind") or "gold_fragments").strip().lower()
    try:
        amount = int(reward.get("amount") if reward.get("amount") is not None else 2)
    except (TypeError, ValueError):
        amount = 2
    amount = max(0, amount)
    # mystery_box is an alias for a fixed fragment grant.
    if kind in ("gold_fragments", "mystery_box") and amount > 0:
        after_a, after_f, _, _ = apply_fragment_delta(
            int(avari.gold_arcori),
            int(avari.gold_fragments),
            amount,
        )
        avari.gold_arcori = after_a
        avari.gold_fragments = after_f
    else:
        after_a, after_f = normalize_wallet(
            int(avari.gold_arcori), int(avari.gold_fragments)
        )

    avari.daily_cache_claimed_at = datetime.now(timezone.utc)
    session.flush()

    goal_row = client_goal_row(goal)
    try:
        notify_daily_completions(
            user_id=user_id,
            day_key=today,
            completed_rows=[goal_row],
        )
    except Exception as exc:  # noqa: BLE001 — claim must still succeed
        if LOGGING_SWITCH:
            customlog(f"daily_goals: claim notify soft-fail goal={gid} err={exc}")

    reward_out: dict[str, Any] = {
        "kind": "gold_fragments" if kind == "mystery_box" else kind,
        "amount": amount,
        "status": "granted",
        "goldArcori": int(after_a),
        "goldFragments": int(after_f),
    }
    if LOGGING_SWITCH:
        customlog(
            f"daily_goals: claim user={user_id} goal={gid} "
            f"frags=+{amount} goldArcori={after_a} frags={after_f}"
        )
    payload = build_progress_payload(
        session,
        user_id=user_id,
        avari=avari,
        changed_goal_ids=[gid],
        no_miss=no_miss,
    )
    payload["reward"] = reward_out
    payload["goal"] = goal_row
    return payload


def parse_goal_id_body(body: dict[str, Any] | None) -> str:
    if not isinstance(body, dict):
        raise AppError(INVALID_QUERY, message="JSON body required")
    gid = str(body.get("goalId") or body.get("goal_id") or "").strip()
    if not gid:
        raise AppError(INVALID_QUERY, message="goalId required")
    return gid
