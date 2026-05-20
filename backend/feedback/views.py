from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from feedback import services
from feedback.serializers import FeedbackCreateSerializer, FeedbackSerializer


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
