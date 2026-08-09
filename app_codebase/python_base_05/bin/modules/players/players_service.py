"""Service-tier AI player sampling for matchmaking fill."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import func, or_, select

from core.errors.app_error import AppError
from core.state.session_scope import session_scope
from core.utils.dev_logger import customlog
from models.avari_profile import AvariProfile
from models.user import User
from modules.players.players_errors import AI_UNAVAILABLE, INVALID_REQUEST

LOGGING_SWITCH = True

AI_SEED_MARKER = "ai_seed:v1"
AI_EMAIL_DOMAIN = "@ai.arcori.local"


def sample_ai_players(
    *,
    count: int,
    exclude_user_ids: list[str] | None = None,
) -> dict[str, Any]:
    if count < 1 or count > 50:
        raise AppError(INVALID_REQUEST, message="count must be 1..50")

    exclude: set[uuid.UUID] = set()
    for raw in exclude_user_ids or []:
        try:
            exclude.add(uuid.UUID(str(raw)))
        except ValueError:
            continue

    with session_scope() as session:
        stmt = (
            select(User.id, User.username, AvariProfile.display_name)
            .join(AvariProfile, AvariProfile.user_id == User.id)
            .where(
                or_(
                    AvariProfile.notes == AI_SEED_MARKER,
                    func.lower(User.email).like(f"%{AI_EMAIL_DOMAIN}"),
                )
            )
            .order_by(func.random())
            .limit(count + len(exclude))
        )
        rows = list(session.execute(stmt).all())

    picked: list[dict[str, Any]] = []
    for user_id, username, display_name in rows:
        if user_id in exclude:
            continue
        picked.append(
            {
                "userId": str(user_id),
                "username": username,
                "displayName": display_name,
            }
        )
        if len(picked) >= count:
            break

    if len(picked) < count:
        raise AppError(
            AI_UNAVAILABLE,
            message=f"Need {count} AI players, got {len(picked)}",
        )

    if LOGGING_SWITCH:
        customlog(
            f"players: ai sample count={count} "
            f"picked={[p['userId'] for p in picked]}"
        )

    return {"players": picked}
