"""In-memory durable-enough store for friend match invites (MVP)."""

from __future__ import annotations

from dataclasses import dataclass
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
    accepted_at: datetime | None = None
    declined_at: datetime | None = None


_INVITES: dict[str, InviteRecord] = {}

# MVP TTL. In practice, align this with the Dart invite lobby lifetime.
_TTL_MINUTES = 10


def reset_friend_match_invites() -> None:
    _INVITES.clear()


def create_invite(*, host_user_id: str, invited_user_id: str) -> str:
    now = datetime.now(timezone.utc)
    invite_id = uuid.uuid4().hex
    record = InviteRecord(
        invite_id=invite_id,
        host_user_id=host_user_id,
        invited_user_id=invited_user_id,
        status="waiting",
        created_at=now,
        expires_at=now + timedelta(minutes=_TTL_MINUTES),
    )
    _INVITES[invite_id] = record
    return invite_id


def get_invite(invite_id: str) -> InviteRecord | None:
    if not invite_id:
        return None
    return _INVITES.get(invite_id)


def _is_expired(record: InviteRecord) -> bool:
    return datetime.now(timezone.utc) >= record.expires_at


def cancel_expired_invites() -> None:
    now = datetime.now(timezone.utc)
    for invite_id, rec in list(_INVITES.items()):
        if now >= rec.expires_at:
            _INVITES.pop(invite_id, None)


def accept_invite(*, invite_id: str, user_id: str) -> None:
    cancel_expired_invites()
    rec = get_invite(invite_id)
    if rec is None:
        raise KeyError("invite_not_found")
    if rec.invited_user_id != user_id:
        raise PermissionError("invite_forbidden")
    if rec.status != "waiting":
        raise RuntimeError("invite_not_pending")
    if _is_expired(rec):
        raise KeyError("invite_not_found")
    rec.status = "accepted"
    rec.accepted_at = datetime.now(timezone.utc)


def decline_invite(*, invite_id: str, user_id: str) -> None:
    cancel_expired_invites()
    rec = get_invite(invite_id)
    if rec is None:
        raise KeyError("invite_not_found")
    if rec.invited_user_id != user_id:
        raise PermissionError("invite_forbidden")
    if rec.status != "waiting":
        raise RuntimeError("invite_not_pending")
    if _is_expired(rec):
        raise KeyError("invite_not_found")
    rec.status = "declined"
    rec.declined_at = datetime.now(timezone.utc)

