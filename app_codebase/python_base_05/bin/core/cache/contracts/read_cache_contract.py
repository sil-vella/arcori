"""Define what read-through caching looks like to feature and service code.

Feature modules call :meth:`ReadCacheContract.get_or_load` without importing ``redis``
or knowing whether Redis is enabled. Tests can pass :class:`~core.cache.noop_read_cache.NoOpReadCache`.
"""

from __future__ import annotations

from typing import Callable, Protocol, TypeVar

T = TypeVar("T")


class ReadCacheContract(Protocol):
    """Shared read-through cache surface for all Gunicorn workers."""

    def is_enabled(self) -> bool:
        """True when backed by Redis (not the no-op implementation)."""
        ...

    def get_or_load(
        self,
        key: str,
        ttl_seconds: int,
        loader: Callable[[], T],
    ) -> T:
        """Return cached value for [key] or call [loader], store, and return."""
        ...

    def delete(self, key: str) -> None:
        """Drop a logical cache key (no-op when cache is disabled)."""
        ...
