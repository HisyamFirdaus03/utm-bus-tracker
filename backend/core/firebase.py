"""
Firebase Admin SDK initialization.

Provides a singleton Firestore client and Auth verifier.
All Firestore access in the project goes through `get_db()`.
"""

import firebase_admin
from firebase_admin import credentials, firestore, auth
from django.conf import settings

_app = None


def _init_firebase():
    global _app
    if _app is not None:
        return

    if settings.FIREBASE_CREDENTIALS_PATH:
        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
    else:
        # Falls back to GOOGLE_APPLICATION_CREDENTIALS env var
        cred = credentials.ApplicationDefault()

    _app = firebase_admin.initialize_app(cred, {
        "projectId": settings.FIREBASE_PROJECT_ID,
    })


def get_db():
    """Return the Firestore client (initialises Firebase on first call)."""
    _init_firebase()
    return firestore.client()


def verify_id_token(id_token: str) -> dict:
    """Verify a Firebase ID token and return the decoded claims."""
    _init_firebase()
    return auth.verify_id_token(id_token)
