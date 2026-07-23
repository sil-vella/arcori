"""Environment-driven HTTP rate-limit settings."""

from __future__ import annotations

import os
from dataclasses import dataclass


BUCKET_GLOBAL = "global"
BUCKET_AUTH = "auth"
BUCKET_AUTH_IDENTITY = "auth_identity"
BUCKET_GUEST_REGISTER = "guest_register"


@dataclass(frozen=True)
class BucketPolicy:
    max_requests: int
    window_s: int


def rate_limit_enabled() -> bool:
    return os.environ.get("ARCORI_RATE_LIMIT_ENABLED", "false").lower() in (
        "1",
        "true",
        "yes",
    )


def rate_limit_key_prefix() -> str:
    return os.environ.get("ARCORI_RATE_LIMIT_KEY_PREFIX", "Arcori:ratelimit:")


def global_policy() -> BucketPolicy:
    return BucketPolicy(
        max_requests=int(os.environ.get("ARCORI_RATE_LIMIT_GLOBAL_MAX", "120")),
        window_s=int(os.environ.get("ARCORI_RATE_LIMIT_GLOBAL_WINDOW_S", "60")),
    )


def auth_policy() -> BucketPolicy:
    return BucketPolicy(
        max_requests=int(os.environ.get("ARCORI_RATE_LIMIT_AUTH_MAX", "20")),
        window_s=int(os.environ.get("ARCORI_RATE_LIMIT_AUTH_WINDOW_S", "60")),
    )


def auth_identity_policy() -> BucketPolicy:
    return BucketPolicy(
        max_requests=int(
            os.environ.get("ARCORI_RATE_LIMIT_AUTH_IDENTITY_MAX", "10")
        ),
        window_s=int(
            os.environ.get("ARCORI_RATE_LIMIT_AUTH_IDENTITY_WINDOW_S", "900")
        ),
    )


def guest_register_policy() -> BucketPolicy:
    return BucketPolicy(
        max_requests=int(
            os.environ.get("ARCORI_RATE_LIMIT_GUEST_REGISTER_MAX", "5")
        ),
        window_s=int(
            os.environ.get("ARCORI_RATE_LIMIT_GUEST_REGISTER_WINDOW_S", "3600")
        ),
    )
