"""
Route & BusStop service — business logic for routes and stops.

Firestore collections: `routes`, `stops`.
"""

from typing import List, Optional

from core.firebase import get_db


ROUTES_COLLECTION = "routes"
STOPS_COLLECTION = "stops"


# ── Bus Stops ──────────────────────────────────────────────────────

def get_all_stops() -> List[dict]:
    docs = get_db().collection(STOPS_COLLECTION).stream()
    result = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        result.append(data)
    return result


def get_stop(stop_id: str) -> Optional[dict]:
    doc = get_db().collection(STOPS_COLLECTION).document(stop_id).get()
    if not doc.exists:
        return None
    data = doc.to_dict()
    data["id"] = stop_id
    return data


def create_stop(data: dict) -> dict:
    ref = get_db().collection(STOPS_COLLECTION).document()
    ref.set(data)
    data["id"] = ref.id
    return data


def update_stop(stop_id: str, updates: dict) -> Optional[dict]:
    ref = get_db().collection(STOPS_COLLECTION).document(stop_id)
    doc = ref.get()
    if not doc.exists:
        return None
    ref.update(updates)
    data = doc.to_dict()
    data.update(updates)
    data["id"] = stop_id
    return data


def delete_stop(stop_id: str) -> bool:
    ref = get_db().collection(STOPS_COLLECTION).document(stop_id)
    doc = ref.get()
    if not doc.exists:
        return False
    ref.delete()
    return True


# ── Routes ─────────────────────────────────────────────────────────

def _populate_stops(route_data: dict) -> dict:
    """Replace stop_ids with full stop objects, sorted by order."""
    stop_ids = route_data.get("stop_ids", [])
    stops = []
    for sid in stop_ids:
        stop = get_stop(sid)
        if stop:
            stops.append(stop)
    stops.sort(key=lambda s: s.get("order", 0))
    route_data["stops"] = stops
    return route_data


def get_all_routes() -> List[dict]:
    docs = get_db().collection(ROUTES_COLLECTION).stream()
    result = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        _populate_stops(data)
        result.append(data)
    return result


def get_route(route_id: str) -> Optional[dict]:
    doc = get_db().collection(ROUTES_COLLECTION).document(route_id).get()
    if not doc.exists:
        return None
    data = doc.to_dict()
    data["id"] = route_id
    _populate_stops(data)
    return data


def create_route(data: dict) -> dict:
    ref = get_db().collection(ROUTES_COLLECTION).document()
    ref.set(data)
    data["id"] = ref.id
    _populate_stops(data)
    return data


def update_route(route_id: str, updates: dict) -> Optional[dict]:
    ref = get_db().collection(ROUTES_COLLECTION).document(route_id)
    doc = ref.get()
    if not doc.exists:
        return None
    ref.update(updates)
    data = doc.to_dict()
    data.update(updates)
    data["id"] = route_id
    _populate_stops(data)
    return data


def delete_route(route_id: str) -> bool:
    ref = get_db().collection(ROUTES_COLLECTION).document(route_id)
    doc = ref.get()
    if not doc.exists:
        return False
    ref.delete()
    return True
