from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from feedback import services
from feedback.serializers import (
    FeedbackCreateSerializer,
    FeedbackRespondSerializer,
    FeedbackSerializer,
)


@api_view(["GET", "POST"])
def feedback_root(request):
    """
    GET  /api/feedbacks/ — list feedback submitted by the authenticated student.
    POST /api/feedbacks/ — create a new feedback row, attributed to the caller.
    """
    if request.method == "GET":
        rows = services.list_feedback_for_student(request.user.uid)
        return Response(FeedbackSerializer(rows, many=True).data)

    serializer = FeedbackCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    row = services.create_feedback(request.user.uid, serializer.validated_data)
    return Response(FeedbackSerializer(row).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
def feedback_list_all(request):
    """GET /api/feedbacks/all/ — list every feedback row (admin only)."""
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    rows = services.list_all_feedback()
    return Response(FeedbackSerializer(rows, many=True).data)


@api_view(["PATCH"])
def feedback_respond(request, feedback_id):
    """PATCH /api/feedbacks/<id>/respond/ — set admin_response and/or status."""
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    serializer = FeedbackRespondSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    row = services.respond_to_feedback(
        feedback_id,
        serializer.validated_data.get("admin_response"),
        serializer.validated_data.get("status"),
    )
    if not row:
        return Response(
            {"detail": "Feedback not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(FeedbackSerializer(row).data)
