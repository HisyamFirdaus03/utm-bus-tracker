from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from routes.serializers import (
    BusRouteSerializer,
    BusRouteCreateSerializer,
    BusStopSerializer,
)
from routes import services


# ── Routes ─────────────────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([AllowAny])
def route_list(request):
    """GET /api/routes/ — list all routes with their stops."""
    routes = services.get_all_routes()
    return Response(BusRouteSerializer(routes, many=True).data)


@api_view(["POST"])
def route_create(request):
    """POST /api/routes/ — create a new route (admin only)."""
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    serializer = BusRouteCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    route = services.create_route(serializer.validated_data)
    return Response(BusRouteSerializer(route).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([AllowAny])
def route_detail(request, route_id):
    """GET /api/routes/<route_id>/ — get a route with stops."""
    route = services.get_route(route_id)
    if not route:
        return Response(
            {"detail": "Route not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(BusRouteSerializer(route).data)


@api_view(["PATCH"])
def route_update(request, route_id):
    """PATCH /api/routes/<route_id>/ — update a route (admin only)."""
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    route = services.update_route(route_id, request.data)
    if not route:
        return Response(
            {"detail": "Route not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(BusRouteSerializer(route).data)


@api_view(["DELETE"])
def route_delete(request, route_id):
    """DELETE /api/routes/<route_id>/ — delete a route (admin only)."""
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    deleted = services.delete_route(route_id)
    if not deleted:
        return Response(
            {"detail": "Route not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(status=status.HTTP_204_NO_CONTENT)


# ── Stops ──────────────────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([AllowAny])
def stop_list(request):
    """GET /api/routes/stops/ — list all bus stops."""
    stops = services.get_all_stops()
    return Response(BusStopSerializer(stops, many=True).data)


@api_view(["POST"])
def stop_create(request):
    """POST /api/routes/stops/ — create a bus stop (admin only)."""
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    serializer = BusStopSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    stop = services.create_stop(serializer.validated_data)
    return Response(BusStopSerializer(stop).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([AllowAny])
def stop_detail(request, stop_id):
    """GET /api/routes/stops/<stop_id>/ — get a single stop."""
    stop = services.get_stop(stop_id)
    if not stop:
        return Response(
            {"detail": "Stop not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(BusStopSerializer(stop).data)


@api_view(["PATCH"])
def stop_update(request, stop_id):
    """PATCH /api/routes/stops/<stop_id>/ — update a stop (admin only)."""
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    stop = services.update_stop(stop_id, request.data)
    if not stop:
        return Response(
            {"detail": "Stop not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(BusStopSerializer(stop).data)


@api_view(["DELETE"])
def stop_delete(request, stop_id):
    """DELETE /api/routes/stops/<stop_id>/ — delete a stop (admin only)."""
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    deleted = services.delete_stop(stop_id)
    if not deleted:
        return Response(
            {"detail": "Stop not found."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(status=status.HTTP_204_NO_CONTENT)
