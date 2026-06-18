"""
DRF authentication backend that verifies Firebase ID tokens.

The Flutter app sends `Authorization: Bearer <firebase_id_token>` with each
request. This class verifies the token and attaches a [FirebaseUser] backed
by the decoded JWT claims to `request.user`.

It deliberately does **not** fetch the user's Firestore profile on every
request — that turned every API call into 1+ Firestore read, which burns
the Spark-plan free quota fast under normal mobile-app load (ETA polling,
hot reloads, stream re-subscribes). The role is in the JWT custom claim
anyway. Views that need full profile fields (name, matric, etc.) — e.g.
`/api/auth/me/` — do their own one-off Firestore read.
"""

from rest_framework import authentication, exceptions

from core.firebase import verify_id_token


class FirebaseUser:
    """Lightweight user object attached to request.user. Backed by JWT claims."""

    def __init__(self, uid, claims):
        self.uid = uid
        self.id = uid
        self.claims = claims  # decoded Firebase ID token claims
        self.is_authenticated = True

    @property
    def role(self):
        # Custom claim, set server-side by `seed_admin` / `seed_driver` /
        # `users.views.register`. Defaults to 'student' for tokens without one.
        return self.claims.get("role", "student")

    @property
    def email(self):
        return self.claims.get("email", "")

    @property
    def name(self):
        return self.claims.get("name", "")

    def __str__(self):
        return self.name or self.uid


class FirebaseAuthentication(authentication.BaseAuthentication):
    """
    Authenticate requests using Firebase ID tokens.

    Header format: Authorization: Bearer <id_token>
    """

    def authenticate_header(self, request):
        # Without this, DRF reports auth failures as 403 instead of 401.
        return 'Bearer realm="api"'

    def authenticate(self, request):
        auth_header = request.META.get("HTTP_AUTHORIZATION", "")
        if not auth_header.startswith("Bearer "):
            return None  # let other auth backends try

        token = auth_header[7:]  # strip "Bearer "

        try:
            decoded = verify_id_token(token)
        except Exception as e:
            raise exceptions.AuthenticationFailed(
                f"Invalid or expired Firebase token: {e}"
            )

        uid = decoded["uid"]
        return (FirebaseUser(uid, decoded), None)
