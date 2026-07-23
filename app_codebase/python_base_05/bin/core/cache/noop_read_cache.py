"""Read-cache implementation that always calls the loader (cache disabled)."""

from __future__ import annotations

from typing import Callable, TypeVar

T = TypeVar("T")


class NoOpReadCache:
    def is_enabled(self) -> bool:
        return False

    def get_or_load(
        self,
        key: str,
        ttl_seconds: int,
        loader: Callable[[], T],
    ) -> T:
        del key, ttl_seconds
        return loader()

    def delete(self, key: str) -> None:
        del key
