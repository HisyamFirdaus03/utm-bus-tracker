"""
Analytics service — aggregates DataLog + existing collections into
chart-ready shapes for the admin Analytics page.

DataLog Firestore collection `data_logs` holds (per SDD):
    timestamp (ISO str), weather (str), number_of_students (int),
    number_of_buses (int), bus_id (str), bus_stop_id (str)

For PSM 2 the collection is populated by `seed_data_logs`.

Caching: every public function on this module is a tiny dict lookup once
the per-collection snapshots are warm. The snapshots are cached in
process memory with a 5-minute TTL — opening the dashboard 100 times in
5 minutes triggers a single Firestore scan. This is what keeps the
project viable on Firebase Spark (50K reads/day) under demo load. Cache
is per-process so it resets whenever Django reloads; for a multi-worker
gunicorn deploy each worker has its own cache, which is fine.

Call `clear_cache()` (or `POST /api/analytics/cache/clear/`) after
seeding/training to see fresh data without waiting for the TTL.
"""

import time
from collections import Counter, defaultdict
from datetime import datetime, timezone, timedelta
from typing import Callable, Optional, TypeVar

from core.firebase import get_db


DATA_LOGS = "data_logs"
FEEDBACKS = "feedbacks"
BUSES = "buses"
ROUTES = "routes"
STOPS = "stops"

# 5 min is short enough that newly seeded data shows up quickly during
# development, long enough that even aggressive dashboard refreshes only
# trigger a single Firestore scan per window.
_TTL_SECONDS = 300

_CACHE: dict[str, tuple[float, object]] = {}

T = TypeVar("T")


def _cached(key: str, fn: Callable[[], T], ttl: int = _TTL_SECONDS) -> T:
    now = time.time()
    entry = _CACHE.get(key)
    if entry is not None and now - entry[0] < ttl:
        return entry[1]  # type: ignore[return-value]
    value = fn()
    _CACHE[key] = (now, value)
    return value


def clear_cache() -> None:
    """Drop every cached snapshot. Next request re-reads Firestore."""
    _CACHE.clear()


def cache_status() -> dict:
    """Diagnostic — useful for debugging stale numbers in the UI."""
    now = time.time()
    return {
        "ttl_seconds": _TTL_SECONDS,
        "entries": [
            {
                "key": key,
                "age_seconds": round(now - ts, 1),
                "size": len(value) if hasattr(value, "__len__") else None,
            }
            for key, (ts, value) in _CACHE.items()
        ],
    }


# ----------------------------------------------------------------------
# Cached Firestore snapshots — one scan per TTL window, shared across
# every public service function below.
# ----------------------------------------------------------------------

def _all_data_logs() -> list[dict]:
    return _cached(
        "data_logs",
        lambda: [d.to_dict() or {} for d in get_db().collection(DATA_LOGS).stream()],
    )


def _all_feedbacks() -> list[dict]:
    return _cached(
        "feedbacks",
        lambda: [d.to_dict() or {} for d in get_db().collection(FEEDBACKS).stream()],
    )


def _all_buses() -> list[dict]:
    return _cached(
        "buses",
        lambda: [d.to_dict() or {} for d in get_db().collection(BUSES).stream()],
    )


def _all_routes() -> list[dict]:
    return _cached(
        "routes",
        lambda: [d.to_dict() or {} for d in get_db().collection(ROUTES).stream()],
    )


def _all_stops_map() -> dict[str, dict]:
    return _cached(
        "stops_map",
        lambda: {
            d.id: (d.to_dict() or {}) for d in get_db().collection(STOPS).stream()
        },
    )


# ----------------------------------------------------------------------
# Internal helpers
# ----------------------------------------------------------------------

def _parse_ts(ts: str) -> Optional[datetime]:
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None


def _iter_data_logs(since: Optional[datetime] = None) -> list[dict]:
    rows = _all_data_logs()
    if since is None:
        return rows
    out = []
    for row in rows:
        t = _parse_ts(row.get("timestamp", ""))
        if t is None or t < since:
            continue
        out.append(row)
    return out


# ----------------------------------------------------------------------
# Public service functions (called by views.py + report.py)
# ----------------------------------------------------------------------

def overview() -> dict:
    """Top-level KPI tiles."""
    buses = _all_buses()
    routes = _all_routes()
    feedback = _all_feedbacks()

    active_buses = sum(1 for b in buses if b.get("status") == "active")
    active_routes = sum(1 for r in routes if r.get("is_active"))

    feedback_status = Counter()
    for f in feedback:
        feedback_status[f.get("status", "new")] += 1

    # Sum students from the most recent day of data_logs (proxy "today")
    since = datetime.now(timezone.utc) - timedelta(days=1)
    riders_today = sum(
        int(row.get("number_of_students", 0) or 0)
        for row in _iter_data_logs(since)
    )

    return {
        "buses_total": len(buses),
        "buses_active": active_buses,
        "routes_total": len(routes),
        "routes_active": active_routes,
        "feedback_total": len(feedback),
        "feedback_new": feedback_status.get("new", 0),
        "feedback_in_progress": feedback_status.get("in_progress", 0),
        "feedback_resolved": feedback_status.get("resolved", 0),
        "riders_last_24h": riders_today,
    }


def ridership_daily(days: int = 30) -> list[dict]:
    """Sum of number_of_students per day for the last `days` days."""
    since = datetime.now(timezone.utc) - timedelta(days=days)
    per_day: dict[str, int] = defaultdict(int)
    for row in _iter_data_logs(since):
        t = _parse_ts(row.get("timestamp", ""))
        if not t:
            continue
        key = t.astimezone(timezone.utc).strftime("%Y-%m-%d")
        per_day[key] += int(row.get("number_of_students", 0) or 0)
    # Fill missing days with zero so charts have a continuous x-axis
    out = []
    today = datetime.now(timezone.utc).date()
    for i in range(days - 1, -1, -1):
        d = today - timedelta(days=i)
        key = d.strftime("%Y-%m-%d")
        out.append({"date": key, "riders": per_day.get(key, 0)})
    return out


def ridership_by_hour() -> list[dict]:
    """Average students per hour-of-day, across all logs (peak-hours view)."""
    since = datetime.now(timezone.utc) - timedelta(days=30)
    totals: dict[int, int] = defaultdict(int)
    counts: dict[int, int] = defaultdict(int)
    for row in _iter_data_logs(since):
        t = _parse_ts(row.get("timestamp", ""))
        if not t:
            continue
        hr = t.astimezone(timezone.utc).hour
        totals[hr] += int(row.get("number_of_students", 0) or 0)
        counts[hr] += 1
    out = []
    for hr in range(24):
        avg = totals[hr] / counts[hr] if counts[hr] else 0
        out.append({"hour": hr, "avg_riders": round(avg, 1)})
    return out


def demand_by_stop(limit: int = 10) -> list[dict]:
    """Total students by stop over last 30 days, top `limit`."""
    stops = _all_stops_map()
    since = datetime.now(timezone.utc) - timedelta(days=30)
    per_stop: dict[str, int] = defaultdict(int)
    for row in _iter_data_logs(since):
        sid = row.get("bus_stop_id")
        if not sid:
            continue
        per_stop[sid] += int(row.get("number_of_students", 0) or 0)

    rows = []
    for sid, total in per_stop.items():
        name = stops.get(sid, {}).get("name", sid)
        rows.append({"stop_id": sid, "stop_name": name, "riders": total})
    rows.sort(key=lambda r: r["riders"], reverse=True)
    return rows[:limit]


def feedback_daily(days: int = 30) -> list[dict]:
    """Count of feedback submissions per day for the last `days` days."""
    since = datetime.now(timezone.utc) - timedelta(days=days)
    per_day: dict[str, int] = defaultdict(int)
    for row in _all_feedbacks():
        t = _parse_ts(row.get("timestamp", ""))
        if not t or t < since:
            continue
        key = t.astimezone(timezone.utc).strftime("%Y-%m-%d")
        per_day[key] += 1
    out = []
    today = datetime.now(timezone.utc).date()
    for i in range(days - 1, -1, -1):
        d = today - timedelta(days=i)
        key = d.strftime("%Y-%m-%d")
        out.append({"date": key, "count": per_day.get(key, 0)})
    return out
