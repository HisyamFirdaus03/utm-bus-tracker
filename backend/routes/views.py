import requests
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


# ── Geocode proxy ──────────────────────────────────────────────────

@api_view(["GET"])
def geocode(request):
    """
    GET /api/routes/geocode/?q=NAME — admin-only best-effort geocoder.
    Uses Nominatim (OpenStreetMap), which is free and key-less. Coverage of
    UTM-specific buildings is partial — the admin UI falls back to a
    "Search Google Maps" link when this returns no match.
    """
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )

    query = request.query_params.get("q", "").strip()
    if not query:
        return Response(
            {"detail": "Query parameter 'q' is required."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    full_query = f"{query}, Universiti Teknologi Malaysia, Skudai, Johor, Malaysia"
    try:
        resp = requests.get(
            "https://nominatim.openstreetmap.org/search",
            params={
                "q": full_query,
                "format": "json",
                "limit": 1,
                "countrycodes": "my",
            },
            headers={"User-Agent": "utm-bustracker-admin/1.0"},
            timeout=10,
        )
        results = resp.json()
    except (requests.RequestException, ValueError) as e:
        return Response(
            {"detail": f"Geocoding request failed: {e}"},
            status=status.HTTP_502_BAD_GATEWAY,
        )

    if not isinstance(results, list) or not results:
        return Response(
            {"detail": f"No match for '{query}'."},
            status=status.HTTP_404_NOT_FOUND,
        )

    top = results[0]
    try:
        lat = float(top["lat"])
        lng = float(top["lon"])
    except (KeyError, ValueError, TypeError):
        return Response(
            {"detail": "Unexpected geocoder response."},
            status=status.HTTP_502_BAD_GATEWAY,
        )

    return Response({
        "lat": lat,
        "lng": lng,
        "formatted_address": top.get("display_name", ""),
    })
