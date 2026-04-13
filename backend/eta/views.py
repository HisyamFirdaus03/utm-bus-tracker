from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status

from eta import services


@api_view(["GET"])
@permission_classes([AllowAny])
def get_eta(request):
    """
    GET /api/eta/?bus_id=xxx&stop_id=yyy

    Returns estimated arrival time of a bus at a given stop.
    """
    bus_id = request.query_params.get("bus_id")
    stop_id = request.query_params.get("stop_id")

    if not bus_id or not stop_id:
        return Response(
            {"detail": "bus_id and stop_id query parameters are required."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    result = services.estimate_eta(bus_id, stop_id)
    if result is None:
        return Response(
            {"detail": "Could not calculate ETA. Bus or stop not found, or bus has no location."},
            status=status.HTTP_404_NOT_FOUND,
        )

    return Response({
        "bus_id": bus_id,
        "stop_id": stop_id,
        "eta_minutes": result["eta_minutes"],
        "distance_meters": result["distance_meters"],
    })
