"""
DRF authentication backend that verifies Firebase ID tokens.

The Flutter app sends `Authorization: Bearer <firebase_id_token>` with each
request. This class verifies the token, looks up the user document in
Firestore, and attaches it to `request.user`.
"""

from rest_framework import authentication, exceptions

from core.firebase import verify_id_token, get_db


class FirebaseUser:
    """Lightweight user object attached to request.user."""

    def __init__(self, uid, data):
        self.uid = uid
        self.id = uid
        self.data = data  # full Firestore user document
        self.is_authenticated = True

    @property
    def role(self):
        return self.data.get("role", "student")

    def __str__(self):
        return self.data.get("name", self.uid)


class FirebaseAuthentication(authentication.BaseAuthentication):
    """
    Authenticate requests using Firebase ID tokens.

    Header format: Authorization: Bearer <id_token>
    """

    def authenticate(self, request):
        auth_header = request.META.get("HTTP_AUTHORIZATION", "")
        if not auth_header.startswith("Bearer "):
            return None  # let other auth backends try

        token = auth_header[7:]  # strip "Bearer "

        try:
            decoded = verify_id_token(token)
        except Exception:
            raise exceptions.AuthenticationFailed("Invalid or expired Firebase token.")

        uid = decoded["uid"]

        # Look up user profile in Firestore
        doc = get_db().collection("users").document(uid).get()
        if doc.exists:
            user_data = doc.to_dict()
            user_data["id"] = uid
        else:
            # First-time login — create a minimal profile from token claims
            user_data = {
                "id": uid,
                "name": decoded.get("name", ""),
                "email": decoded.get("email", ""),
                "role": "student",
            }

        return (FirebaseUser(uid, user_data), None)
