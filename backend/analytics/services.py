"""
Analytics service — aggregates DataLog + existing collections into
chart-ready shapes for the admin Analytics page.

DataLog Firestore collection `data_logs` holds (per SDD):
    timestamp (ISO str), weather (str), number_of_students (int),
    number_of_buses (int), bus_id (str), bus_stop_id (str)

For PSM 2 the collection is populated by `seed_data_logs`.
"""

from collections import Counter, defaultdict
from datetime import datetime, timezone, timedelta
from typing import Iterable, Optional

from core.firebase import get_db


DATA_LOGS = "data_logs"
FEEDBACKS = "feedbacks"
BUSES = "buses"
ROUTES = "routes"
STOPS = "stops"


def _parse_ts(ts: str) -> Optional[datetime]:
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None


def _iter_data_logs(since: Optional[datetime] = None) -> Iterable[dict]:
    docs = get_db().collection(DATA_LOGS).stream()
    for doc in docs:
        row = doc.to_dict() or {}
        if since is not None:
            t = _parse_ts(row.get("timestamp", ""))
            if t is None or t < since:
                continue
        yield row


def overview() -> dict:
    """Top-level KPI tiles."""
    db = get_db()
    buses = list(db.collection(BUSES).stream())
    routes = list(db.collection(ROUTES).stream())
    feedback = list(db.collection(FEEDBACKS).stream())

    active_buses = sum(1 for b in buses if (b.to_dict() or {}).get("status") == "active")
    active_routes = sum(1 for r in routes if (r.to_dict() or {}).get("is_active"))

    feedback_status = Counter()
    for f in feedback:
        feedback_status[(f.to_dict() or {}).get("status", "new")] += 1

    # Sum students from the most recent day of data_logs (proxy "today")
    since = datetime.now(timezone.utc) - timedelta(days=1)
    riders_today = 0
    for row in _iter_data_logs(since):
        riders_today += int(row.get("number_of_students", 0) or 0)

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
    db = get_db()
    stops = {doc.id: (doc.to_dict() or {}) for doc in db.collection(STOPS).stream()}

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
    docs = get_db().collection(FEEDBACKS).stream()
    for doc in docs:
        row = doc.to_dict() or {}
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
