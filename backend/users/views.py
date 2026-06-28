from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from users.serializers import (
    DriverCreateSerializer,
    DriverUpdateSerializer,
    RegisterSerializer,
    UserSerializer,
)
from users import services


def _admin_required(request):
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    return None


@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    """POST /api/auth/register — create a new user account."""
    serializer = RegisterSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    user_data = services.register_user(serializer.validated_data)

    return Response(
        UserSerializer(user_data).data,
        status=status.HTTP_201_CREATED,
    )


@api_view(["GET"])
def me(request):
    """GET /api/auth/me — return the authenticated user's profile."""
    user_data = services.get_user(request.user.uid)
    if not user_data:
        return Response(
            {"detail": "User profile not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(UserSerializer(user_data).data)


@api_view(["PATCH"])
def update_profile(request):
    """PATCH /api/auth/me — update the authenticated user's profile."""
    allowed_fields = {"name", "phone_no", "matric_number"}
    updates = {k: v for k, v in request.data.items() if k in allowed_fields}
    if not updates:
        return Response(
            {"detail": "No valid fields to update."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user_data = services.update_user(request.user.uid, updates)
    if not user_data:
        return Response(
            {"detail": "User profile not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(UserSerializer(user_data).data)


# ----------------------------------------------------------------------
# Admin-only driver management
# ----------------------------------------------------------------------

@api_view(["GET"])
def list_drivers(request):
    """GET /api/auth/drivers/ — list all drivers (with assigned-bus info)."""
    deny = _admin_required(request)
    if deny:
        return deny
    return Response(services.list_drivers())


@api_view(["POST"])
def create_driver(request):
    """POST /api/auth/drivers/ — provision a new driver account."""
    deny = _admin_required(request)
    if deny:
        return deny
    serializer = DriverCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    driver = services.create_driver(serializer.validated_data)
    return Response(driver, status=status.HTTP_201_CREATED)


@api_view(["PATCH"])
def update_driver(request, uid):
    """PATCH /api/auth/drivers/<uid>/ — update name/phone."""
    deny = _admin_required(request)
    if deny:
        return deny
    serializer = DriverUpdateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    if not serializer.validated_data:
        return Response(
            {"detail": "No valid fields to update."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    updated = services.update_user(uid, serializer.validated_data)
    if not updated:
        return Response(
            {"detail": "Driver not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(updated)


@api_view(["DELETE"])
def delete_driver(request, uid):
    """DELETE /api/auth/drivers/<uid>/ — remove driver from Auth + Firestore.

    Also clears any bus.driver_id pointing at this driver."""
    deny = _admin_required(request)
    if deny:
        return deny
    ok = services.delete_driver(uid)
    if not ok:
        return Response(
            {"detail": "Driver not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(status=status.HTTP_204_NO_CONTENT)
