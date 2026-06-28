"""
Bus service — business logic for bus CRUD and location updates.

All Firestore interactions for the `buses` collection live here.
"""

from datetime import datetime, timezone
from typing import List, Optional

from core.firebase import get_db


COLLECTION = "buses"


def _sync_driver_assignment(
    bus_id: str,
    old_driver_id: Optional[str],
    new_driver_id: Optional[str],
) -> None:
    """Keep `buses.driver_id` and `users.assigned_bus_id` in sync.

    When a bus's driver field changes, we must also:
      1. Clear `assigned_bus_id` on the *previous* driver (they're no longer
         on this bus).
      2. If the *new* driver was already on another bus, clear that other
         bus's `driver_id` (one driver, one bus).
      3. Point the *new* driver's `assigned_bus_id` at this bus.

    Without this, the Drivers page and the bus-assignment dropdown drift
    out of sync with reality.
    """
    if (old_driver_id or None) == (new_driver_id or None):
        return  # No-op — nothing changed.

    db = get_db()

    if old_driver_id:
        old_ref = db.collection("users").document(old_driver_id)
        if old_ref.get().exists:
            old_ref.update({"assigned_bus_id": None})

    if new_driver_id:
        new_ref = db.collection("users").document(new_driver_id)
        new_doc = new_ref.get()
        if not new_doc.exists:
            return  # Caller passed a bogus driver_id; bus is already updated.
        prev_bus_id = (new_doc.to_dict() or {}).get("assigned_bus_id")
        if prev_bus_id and prev_bus_id != bus_id:
            db.collection("buses").document(prev_bus_id).update({"driver_id": None})
        new_ref.update({"assigned_bus_id": bus_id})


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
    if data.get("driver_id"):
        _sync_driver_assignment(ref.id, None, data["driver_id"])
    return data


def update_bus(bus_id: str, updates: dict) -> Optional[dict]:
    """Partially update a bus document."""
    ref = get_db().collection(COLLECTION).document(bus_id)
    doc = ref.get()
    if not doc.exists:
        return None
    current = doc.to_dict() or {}
    old_driver_id = current.get("driver_id")
    ref.update(updates)
    if "driver_id" in updates:
        _sync_driver_assignment(bus_id, old_driver_id, updates.get("driver_id"))
    data = current
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
    driver_id = (doc.to_dict() or {}).get("driver_id")
    ref.delete()
    if driver_id:
        _sync_driver_assignment(bus_id, driver_id, None)
    return True
