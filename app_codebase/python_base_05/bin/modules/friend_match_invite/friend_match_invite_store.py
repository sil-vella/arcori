"""In-memory durable-enough store for friend match invites (MVP)."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
import uuid


@dataclass
class InviteRecord:
    invite_id: str
    host_user_id: str
    invited_user_id: str
    status: str  # waiting | accepted | declined
    created_at: datetime
    expires_at: datetime
    invited_user_ids: list[str] = field(default_factory=list)
    accepted_user_ids: list[str] = field(default_factory=list)
    kind: str = "friend"  # friend | rematch
    series_id: str | None = None
    series_index: int | None = None
    prior_match_id: str | None = None
    accepted_at: datetime | None = None
    declined_at: datetime | None = None

    def all_invited_user_ids(self) -> list[str]:
        if self.invited_user_ids:
            return list(self.invited_user_ids)
        if self.invited_user_id:
            return [self.invited_user_id]
        return []


_INVITES: dict[str, InviteRecord] = {}

# Align with Dart invite lobby fill window (20s) plus a short grace for WS lag.
_TTL_SECONDS = 45


def reset_friend_match_invites() -> None:
    _INVITES.clear()


def create_invite(*, host_user_id: str, invited_user_id: str) -> str:
    now = datetime.now(timezone.utc)
    invite_id = uuid.uuid4().hex
    record = InviteRecord(
        invite_id=invite_id,
        host_user_id=host_user_id,
        invited_user_id=invited_user_id,
        invited_user_ids=[invited_user_id],
        status="waiting",
        created_at=now,
        expires_at=now + timedelta(seconds=_TTL_SECONDS),
        kind="friend",
    )
    _INVITES[invite_id] = record
    return invite_id


def create_rematch_invite(
    *,
    host_user_id: str,
    invited_user_ids: list[str],
    prior_match_id: str,
    series_id: str,
    series_index: int,
) -> str:
    cleaned: list[str] = []
    seen: set[str] = set()
    for raw in invited_user_ids:
        uid = str(raw).strip()
        if not uid or uid in seen or uid == host_user_id:
            continue
        seen.add(uid)
        cleaned.append(uid)
    if not cleaned:
        raise ValueError("invited_user_ids required")
    if series_index < 2:
        raise ValueError("series_index must be >= 2")
    series = str(series_id).strip()
    prior = str(prior_match_id).strip()
    if not series or not prior:
        raise ValueError("series_id and prior_match_id required")

    now = datetime.now(timezone.utc)
    invite_id = uuid.uuid4().hex
    record = InviteRecord(
        invite_id=invite_id,
        host_user_id=host_user_id,
        invited_user_id=cleaned[0],
        invited_user_ids=cleaned,
        status="waiting",
        created_at=now,
        expires_at=now + timedelta(seconds=_TTL_SECONDS),
        kind="rematch",
        series_id=series,
        series_index=series_index,
        prior_match_id=prior,
    )
    _INVITES[invite_id] = record
    return invite_id


def get_invite(invite_id: str) -> InviteRecord | None:
    if not invite_id:
        return None
    return _INVITES.get(invite_id)


def pop_invite(invite_id: str) -> InviteRecord | None:
    if not invite_id:
        return None
    return _INVITES.pop(invite_id, None)


def _is_expired(record: InviteRecord) -> bool:
    return datetime.now(timezone.utc) >= record.expires_at


def cancel_expired_invites() -> list[InviteRecord]:
    """Remove expired invites from memory. Returns the removed records."""
    now = datetime.now(timezone.utc)
    expired: list[InviteRecord] = []
    for invite_id, rec in list(_INVITES.items()):
        if now >= rec.expires_at:
            removed = _INVITES.pop(invite_id, None)
            if removed is not None:
                expired.append(removed)
    return expired


def accept_invite(*, invite_id: str, user_id: str) -> InviteRecord:
    cancel_expired_invites()
    rec = get_invite(invite_id)
    if rec is None:
        raise KeyError("invite_not_found")
    invited = rec.all_invited_user_ids()
    if user_id not in invited:
        raise PermissionError("invite_forbidden")
    if rec.status == "declined":
        raise RuntimeError("invite_not_pending")
    if _is_expired(rec):
        pop_invite(invite_id)
        raise KeyError("invite_not_found")
    if user_id not in rec.accepted_user_ids:
        rec.accepted_user_ids.append(user_id)
    rec.accepted_at = datetime.now(timezone.utc)
    # Multi-invitee rematch: stay waiting until every invitee has accepted.
    if len(rec.accepted_user_ids) >= len(invited):
        rec.status = "accepted"
    else:
        rec.status = "waiting"
    return rec


def decline_invite(*, invite_id: str, user_id: str) -> InviteRecord:
    cancel_expired_invites()
    rec = get_invite(invite_id)
    if rec is None:
        raise KeyError("invite_not_found")
    invited = rec.all_invited_user_ids()
    if user_id not in invited:
        raise PermissionError("invite_forbidden")
    if rec.status == "declined":
        raise RuntimeError("invite_not_pending")
    if _is_expired(rec):
        pop_invite(invite_id)
        raise KeyError("invite_not_found")
    rec.status = "declined"
    rec.declined_at = datetime.now(timezone.utc)
    # Decline ends the invite immediately — remove so resolve cannot revive it.
    return pop_invite(invite_id) or rec
