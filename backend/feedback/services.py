"""
Feedback service — business logic for student feedback CRUD.

Firestore collection `feedbacks` holds:
    student_id (Firebase uid), bus_id, description, screenshot_url (nullable),
    status (new|in_progress|resolved), admin_response (nullable), timestamp.
"""

from datetime import datetime, timezone
from typing import List, Optional

from core.firebase import get_db


COLLECTION = "feedbacks"


def create_feedback(student_id: str, data: dict) -> dict:
    """Create a feedback document attributed to `student_id`."""
    payload = {
        "student_id": student_id,
        "bus_id": data["bus_id"],
        "description": data["description"],
        "screenshot_url": data.get("screenshot_url"),
        "status": "new",
        "admin_response": None,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    ref = get_db().collection(COLLECTION).document()
    ref.set(payload)
    payload["id"] = ref.id
    return payload


def list_feedback_for_student(student_id: str) -> List[dict]:
    """Return all feedback rows submitted by `student_id`, newest first."""
    docs = (
        get_db()
        .collection(COLLECTION)
        .where("student_id", "==", student_id)
        .stream()
    )
    result = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        result.append(data)
    # Firestore orderBy on a where-filtered field requires a composite index;
    # sort in memory instead since per-student volumes are tiny.
    result.sort(key=lambda f: f.get("timestamp", ""), reverse=True)
    return result


def get_feedback(feedback_id: str) -> Optional[dict]:
    doc = get_db().collection(COLLECTION).document(feedback_id).get()
    if not doc.exists:
        return None
    data = doc.to_dict()
    data["id"] = feedback_id
    return data
