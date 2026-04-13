from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from users.serializers import RegisterSerializer, UserSerializer
from users import services


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
    allowed_fields = {"name", "phone_no", "faculty", "year", "matric_number"}
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
