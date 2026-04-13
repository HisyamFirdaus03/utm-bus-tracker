"""
Bus service — business logic for bus CRUD and location updates.

All Firestore interactions for the `buses` collection live here.
"""

from datetime import datetime, timezone
from typing import List, Optional

from core.firebase import get_db


COLLECTION = "buses"


def get_all_buses() -> List[dict]:
    """Return all buses."""
    docs = get_db().collection(COLLECTION).stream()
    result = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        result.append(data)
    return result


def get_bus(bus_id: str) -> Optional[dict]:
    """Fetch a single bus by ID."""
    doc = get_db().collection(COLLECTION).document(bus_id).get()
    if not doc.exists:
        return None
    data = doc.to_dict()
    data["id"] = bus_id
    return data


def create_bus(data: dict) -> dict:
    """Create a new bus document. Returns the created document with ID."""
    ref = get_db().collection(COLLECTION).document()
    data["last_updated"] = None
    ref.set(data)
    data["id"] = ref.id
    return data


def update_bus(bus_id: str, updates: dict) -> Optional[dict]:
    """Partially update a bus document."""
    ref = get_db().collection(COLLECTION).document(bus_id)
    doc = ref.get()
    if not doc.exists:
        return None
    ref.update(updates)
    data = doc.to_dict()
    data.update(updates)
    data["id"] = bus_id
    return data


def update_location(bus_id: str, latitude: float, longitude: float,
                    speed: float = 0.0) -> Optional[dict]:
    """Update the GPS location of a bus (called by driver app)."""
    ref = get_db().collection(COLLECTION).document(bus_id)
    doc = ref.get()
    if not doc.exists:
        return None

    updates = {
        "latitude": latitude,
        "longitude": longitude,
        "speed": speed,
        "last_updated": datetime.now(timezone.utc).isoformat(),
        "status": "active",
    }
    ref.update(updates)

    data = doc.to_dict()
    data.update(updates)
    data["id"] = bus_id
    return data


def delete_bus(bus_id: str) -> bool:
    """Delete a bus document. Returns True if it existed."""
    ref = get_db().collection(COLLECTION).document(bus_id)
    doc = ref.get()
    if not doc.exists:
        return False
    ref.delete()
    return True
