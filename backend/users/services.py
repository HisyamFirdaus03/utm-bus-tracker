"""
User service — business logic for user registration and profile management.

All Firestore interactions for the `users` collection live here.
"""

from typing import Optional

from firebase_admin import auth as firebase_auth

from core.firebase import get_db


def register_user(data: dict) -> dict:
    """
    Create a new user in Firebase Auth and store their profile in Firestore.

    Returns the full user document dict (including `id`).
    """
    role = data.get("role", "student")

    firebase_user = firebase_auth.create_user(
        email=data["email"],
        password=data["password"],
        display_name=data["name"],
    )
    uid = firebase_user.uid

    # Custom claim lets Firebase RTDB rules gate driver writes without a Firestore lookup
    firebase_auth.set_custom_user_claims(uid, {"role": role})

    profile = {
        "name": data["name"],
        "email": data["email"],
        "role": role,
    }

    if role == "student":
        profile["matric_number"] = data.get("matric_number")
    elif role == "driver":
        profile["phone_no"] = data.get("phone_no")
        # Per SDD §5.5.2 the Driver entity does NOT carry the bus reference;
        # `bus.driver_id` is the single source of truth. To find a driver's
        # bus, query `buses` where `driver_id == uid` (see list_drivers).

    get_db().collection("users").document(uid).set(profile)

    profile["id"] = uid
    return profile


def get_user(uid: str) -> Optional[dict]:
    """Fetch a user profile from Firestore by UID."""
    doc = get_db().collection("users").document(uid).get()
    if not doc.exists:
        return None
    data = doc.to_dict()
    data["id"] = uid
    return data


def update_user(uid: str, updates: dict) -> Optional[dict]:
    """Partially update a user profile in Firestore."""
    ref = get_db().collection("users").document(uid)
    doc = ref.get()
    if not doc.exists:
        return None
    ref.update(updates)
    data = doc.to_dict()
    data.update(updates)
    data["id"] = uid
    return data


# ----------------------------------------------------------------------
# Driver management (admin-only)
# ----------------------------------------------------------------------

def list_drivers() -> list[dict]:
    """All users with role=driver, joined with their currently assigned bus.

    Source of truth for the relationship is `bus.driver_id` (per SDD §5.5.2),
    so we build a `driver_id → bus` map in one pass over the buses collection
    instead of reading a denormalized field on the user document.
    """
    db = get_db()

    bus_by_driver: dict[str, dict] = {}
    for doc in db.collection("buses").stream():
        bus = doc.to_dict() or {}
        driver_id = bus.get("driver_id")
        if driver_id:
            bus_by_driver[driver_id] = {
                "id": doc.id,
                "plate_number": bus.get("plate_number"),
                "bus_name": bus.get("bus_name"),
            }

    drivers = []
    for doc in db.collection("users").where("role", "==", "driver").stream():
        data = doc.to_dict() or {}
        data["id"] = doc.id
        data["assigned_bus"] = bus_by_driver.get(doc.id)
        drivers.append(data)
    drivers.sort(key=lambda d: (d.get("name") or "").lower())
    return drivers


def create_driver(data: dict) -> dict:
    """Admin-side driver provisioning. Creates Firebase Auth user with
    role=driver custom claim + writes Firestore profile. Mirrors the
    `seed_driver` management command but without the bus link (admin picks
    the bus separately in the Buses page)."""
    firebase_user = firebase_auth.create_user(
        email=data["email"],
        password=data["password"],
        display_name=data["name"],
    )
    uid = firebase_user.uid
    firebase_auth.set_custom_user_claims(uid, {"role": "driver"})

    profile = {
        "name": data["name"],
        "email": data["email"],
        "role": "driver",
        "phone_no": data.get("phone_no", ""),
    }
    get_db().collection("users").document(uid).set(profile)
    profile["id"] = uid
    profile["assigned_bus"] = None  # New driver — not on any bus yet
    return profile


def delete_driver(uid: str) -> bool:
    """Remove a driver from Firebase Auth + Firestore, and clear any
    bus.driver_id pointing at them. Returns False if the user doesn't exist."""
    db = get_db()
    user_ref = db.collection("users").document(uid)
    if not user_ref.get().exists:
        return False

    # Detach any buses currently pointing at this driver.
    for bus_doc in db.collection("buses").where("driver_id", "==", uid).stream():
        bus_doc.reference.update({"driver_id": None})

    user_ref.delete()

    try:
        firebase_auth.delete_user(uid)
    except firebase_auth.UserNotFoundError:
        # Firebase Auth already deleted (drifted state) — Firestore is now
        # consistent, which is what matters.
        pass

    return True
