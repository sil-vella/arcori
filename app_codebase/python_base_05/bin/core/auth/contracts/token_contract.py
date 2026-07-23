"""Token issue and verify surface for feature and guard code."""

from __future__ import annotations

from typing import Any, Protocol

from core.auth.contracts.auth_context_contract import AuthContext


class TokenServiceContract(Protocol):
    def issue_access(self, user_id: str, extra_claims: dict[str, Any] | None = None) -> str: ...

    def issue_refresh(self, user_id: str, extra_claims: dict[str, Any] | None = None) -> str: ...

    def verify_access(self, token: str) -> AuthContext: ...

    def verify_refresh(self, token: str) -> AuthContext: ...
