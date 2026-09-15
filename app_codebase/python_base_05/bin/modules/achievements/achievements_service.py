"""Achievements business logic — catalog read + match unlock apply."""

from __future__ import annotations

from typing import Any

from sqlalchemy.orm import Session

from core.utils.dev_logger import customlog
from modules.achievements import achievements_repository as repo
from modules.achievements.achievements_evaluators import compute_new_unlock_ids
from modules.achievements.achievements_loader import (
    achievement_by_id,
    catalog_revision,
    list_achievements,
    load_achievements_document,
)
from core.utils.media_fields import media_for_client

LOGGING_SWITCH = True


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


def client_achievement_row(entry: dict[str, Any]) -> dict[str, Any]:
    action = entry.get("post_achieve_action")
    if not isinstance(action, dict):
        action = {"type": "none"}
    return {
        "id": entry.get("id"),
        "achievementName": entry.get("achievement_name"),
        "description": entry.get("description") or "",
        "achievementType": entry.get("achievement_type"),
        "params": entry.get("params") or {},
        "media": media_for_client(entry.get("media") if isinstance(entry.get("media"), dict) else {}),
        "postAchieveAction": _camel_post_action(action),
    }


def get_catalog_payload() -> dict[str, Any]:
    doc, revision = load_achievements_document()
    rows = [client_achievement_row(e) for e in (doc.get("achievements") or [])]
    return {
        "revision": revision,
        "schemaVersion": int(doc.get("schema_version") or 1),
        "achievements": rows,
    }


def get_unlocked_payload(session: Session, user_id: str) -> dict[str, Any]:
    ids = repo.list_unlocked_ids(session, user_id)
    return {
        "ids": ids,
        "revision": catalog_revision(),
    }


def apply_win_streak(*, current: int, best: int, won: bool) -> tuple[int, int]:
    if won:
        nxt = max(0, int(current)) + 1
    else:
        nxt = 0
    new_best = max(int(best), nxt)
    return nxt, new_best


def apply_match_unlocks(
    session: Session,
    *,
    user_id: str,
    wins: int,
    matches_played: int,
    flips: int,
    win_streak_current: int,
    is_winner: bool,
    mastery_after: dict[str, int],
    match_flags: set[str] | None = None,
    event_id: str | None = None,
    event_progress: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Evaluate catalog against post-match context; persist new unlocks; return client rows."""
    catalog = list_achievements()
    if not catalog:
        return []
    already = repo.unlocked_id_set(session, user_id)
    ctx: dict[str, Any] = {
        "wins": int(wins),
        "matches_played": int(matches_played),
        "flips": int(flips),
        "win_streak_current": int(win_streak_current),
        "is_winner": bool(is_winner),
        "match_flags": set(match_flags or set()),
        "mastery_after": dict(mastery_after or {}),
        "event_id": (event_id or "").strip() or None,
        "event_progress": dict(event_progress or {}),
    }
    new_ids = compute_new_unlock_ids(catalog, already, ctx)
    if not new_ids:
        return []
    inserted = repo.insert_unlocks(session, user_id=user_id, achievement_ids=new_ids)
    # Preserve catalog order for inserted set
    inserted_set = set(inserted)
    ordered = [aid for aid in new_ids if aid in inserted_set]
    out: list[dict[str, Any]] = []
    for aid in ordered:
        entry = achievement_by_id(aid)
        if entry is None:
            continue
        out.append(client_achievement_row(entry))
    if LOGGING_SWITCH and out:
        customlog(
            f"achievements: unlocked user={user_id} "
            f"ids={[r.get('id') for r in out]}"
        )
    return out
