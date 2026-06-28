"""
Bus service — business logic for bus CRUD and location updates.

All Firestore interactions for the `buses` collection live here.
"""

from datetime import datetime, timezone
from typing import List, Optional

from core.firebase import get_db


COLLECTION = "buses"


def _detach_other_buses(bus_id: str, new_driver_id: Optional[str]) -> None:
    """Enforce one-driver-one-bus.

    Per SDD §5.5.2, the driver↔bus relationship lives entirely on
    `bus.driver_id`. If the admin assigns driver X to bus B, we must also
    clear `driver_id` on any *other* bus that's still pointing at X.
    """
    if not new_driver_id:
        return
    db = get_db()
    for doc in db.collection(COLLECTION).where("driver_id", "==", new_driver_id).stream():
        if doc.id != bus_id:
            doc.reference.update({"driver_id": None})


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
    _detach_other_buses(ref.id, data.get("driver_id"))
    return data


def update_bus(bus_id: str, updates: dict) -> Optional[dict]:
    """Partially update a bus document."""
    ref = get_db().collection(COLLECTION).document(bus_id)
    doc = ref.get()
    if not doc.exists:
        return None
    ref.update(updates)
    if "driver_id" in updates:
        _detach_other_buses(bus_id, updates.get("driver_id"))
    data = doc.to_dict() or {}
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
    """Delete a bus document. Returns True if it existed.

    Nothing else to clean up — driver↔bus is one-sided per SDD §5.5.2,
    so once the bus doc is gone, any other reference to it is dead by
    construction.
    """
    ref = get_db().collection(COLLECTION).document(bus_id)
    doc = ref.get()
    if not doc.exists:
        return False
    ref.delete()
    return True
