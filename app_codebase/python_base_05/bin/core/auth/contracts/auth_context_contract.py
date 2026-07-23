"""Authenticated user context attached after JWT verification."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class AuthContext:
    user_id: str
    claims: dict[str, Any]
