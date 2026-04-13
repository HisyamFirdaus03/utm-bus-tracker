from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from buses.serializers import BusSerializer, UpdateLocationSerializer
from buses import services


@api_view(["GET"])
@permission_classes([AllowAny])
def bus_list(request):
    """GET /api/buses/ — list all buses."""
    buses = services.get_all_buses()
    serializer = BusSerializer(buses, many=True)
    return Response(serializer.data)


@api_view(["POST"])
def bus_create(request):
    """POST /api/buses/ — create a new bus (admin only)."""
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    serializer = BusSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    bus = services.create_bus(serializer.validated_data)
    return Response(BusSerializer(bus).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([AllowAny])
def bus_detail(request, bus_id):
    """GET /api/buses/<bus_id>/ — get a single bus."""
    bus = services.get_bus(bus_id)
    if not bus:
        return Response(
            {"detail": "Bus not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(BusSerializer(bus).data)


@api_view(["PATCH"])
def bus_update(request, bus_id):
    """PATCH /api/buses/<bus_id>/ — update bus fields (admin only)."""
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    bus = services.update_bus(bus_id, request.data)
    if not bus:
        return Response(
            {"detail": "Bus not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(BusSerializer(bus).data)


@api_view(["DELETE"])
def bus_delete(request, bus_id):
    """DELETE /api/buses/<bus_id>/ — delete a bus (admin only)."""
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    deleted = services.delete_bus(bus_id)
    if not deleted:
        return Response(
            {"detail": "Bus not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
def bus_update_location(request, bus_id):
    """POST /api/buses/<bus_id>/location/ — driver updates bus GPS position."""
    if request.user.role != "driver":
        return Response(
            {"detail": "Driver access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    serializer = UpdateLocationSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    bus = services.update_location(
        bus_id,
        serializer.validated_data["latitude"],
        serializer.validated_data["longitude"],
        serializer.validated_data.get("speed", 0.0),
    )
    if not bus:
        return Response(
            {"detail": "Bus not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(BusSerializer(bus).data)
