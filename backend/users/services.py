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
        profile["faculty"] = data.get("faculty")
        profile["year"] = data.get("year")
    elif role == "driver":
        profile["phone_no"] = data.get("phone_no")
        profile["assigned_bus_id"] = None

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
