"""
Tiny in-process TTL cache shared across services.

Why this exists: we're on the Firebase Spark plan (50k reads/day). Every
`GET /api/buses/`, `/api/routes/`, `/api/eta/` etc. scans a collection —
that adds up fast on demo day. Caching flattens the per-request read
cost to zero within the TTL window; a cache miss re-reads and re-warms.

Trade-off: per-process cache (this module lives in Django's process
memory), so with N gunicorn workers each has its own cache. Cold cost
per worker on first hit, but shared across all subsequent requests to
that worker.

Cache-affecting writes MUST call `invalidate(key)` (or use the
`@cached_read` decorator which handles it via the paired
`@invalidates(...)` decorator).
"""

import time
from typing import Callable, Optional, TypeVar


T = TypeVar("T")


class _Store:
    """Namespaced (name, args)-keyed cache with per-key TTL tracking."""

    def __init__(self) -> None:
        self._entries: dict[str, tuple[float, object]] = {}

    def get(self, key: str, ttl: int) -> Optional[object]:
        entry = self._entries.get(key)
        if entry is None:
            return None
        ts, value = entry
        if time.time() - ts > ttl:
            return None
        return value

    def set(self, key: str, value: object) -> None:
        self._entries[key] = (time.time(), value)

    def invalidate(self, prefix: str) -> None:
        """Drop every entry whose key starts with `prefix` (usually the
        cache name — so `invalidate("buses")` clears all `buses:*` args)."""
        for key in [k for k in self._entries if k.startswith(prefix)]:
            self._entries.pop(key, None)

    def clear(self) -> None:
        self._entries.clear()

    def status(self) -> dict:
        now = time.time()
        return {
            "entries": [
                {
                    "key": k,
                    "age_seconds": round(now - ts, 1),
                    "size": len(v) if hasattr(v, "__len__") else None,
                }
                for k, (ts, v) in self._entries.items()
            ],
        }


_STORE = _Store()


def cached_read(name: str, ttl: int) -> Callable:
    """Decorator: cache the result of a read function for `ttl` seconds.

    The cache key is `name:repr(args):repr(kwargs)`, so different arg
    combinations get separate cache entries. Use with pure reads only —
    write functions should call `invalidate(name)` themselves.
    """

    def wrap(fn: Callable[..., T]) -> Callable[..., T]:
        def inner(*args, **kwargs) -> T:
            key = f"{name}:{args!r}:{sorted(kwargs.items())!r}"
            hit = _STORE.get(key, ttl)
            if hit is not None:
                return hit  # type: ignore[return-value]
            value = fn(*args, **kwargs)
            _STORE.set(key, value)
            return value
        inner.__name__ = fn.__name__
        inner.__doc__ = fn.__doc__
        return inner

    return wrap


def invalidate(name: str) -> None:
    """Drop every cache entry belonging to `name` (matches by prefix)."""
    _STORE.invalidate(f"{name}:")


def clear_all() -> None:
    _STORE.clear()


def status() -> dict:
    return _STORE.status()
