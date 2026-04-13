"""
ETA service — estimates bus arrival time using Google Distance Matrix API.

Algorithm (from SDD 5.9.2):
1. Accept origin (bus lat/lng) and destination (stop lat/lng) as input.
2. Call Google Distance Matrix API with inputs.
3. Parse API response to retrieve duration.value.
4. Return ETA in minutes.
"""

from typing import Optional

import requests
from django.conf import settings

from buses.services import get_bus
from routes.services import get_stop


def estimate_eta(bus_id: str, stop_id: str) -> Optional[dict]:
    """
    Calculate ETA in minutes from a bus's current position to a stop.

    Returns {"eta_minutes": int, "distance_meters": int} or None if inputs
    are invalid.
    """
    bus = get_bus(bus_id)
    if not bus or not bus.get("latitude") or not bus.get("longitude"):
        return None

    stop = get_stop(stop_id)
    if not stop:
        return None

    origin = f"{bus['latitude']},{bus['longitude']}"
    destination = f"{stop['latitude']},{stop['longitude']}"

    api_key = settings.GOOGLE_MAPS_API_KEY
    if not api_key:
        # Fallback: rough estimate based on straight-line distance
        return _fallback_estimate(bus, stop)

    resp = requests.get(
        "https://maps.googleapis.com/maps/api/distancematrix/json",
        params={
            "origins": origin,
            "destinations": destination,
            "mode": "driving",
            "key": api_key,
        },
        timeout=10,
    )
    data = resp.json()

    try:
        element = data["rows"][0]["elements"][0]
        if element["status"] != "OK":
            return _fallback_estimate(bus, stop)
        duration_seconds = element["duration"]["value"]
        distance_meters = element["distance"]["value"]
        return {
            "eta_minutes": round(duration_seconds / 60),
            "distance_meters": distance_meters,
        }
    except (KeyError, IndexError):
        return _fallback_estimate(bus, stop)


def _fallback_estimate(bus: dict, stop: dict) -> dict:
    """Rough ETA based on straight-line distance and assumed 30 km/h speed."""
    import math

    lat1, lon1 = bus["latitude"], bus["longitude"]
    lat2, lon2 = stop["latitude"], stop["longitude"]

    # Haversine formula
    R = 6371000  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = (math.sin(dphi / 2) ** 2
         + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    distance_meters = R * c

    # Assume 30 km/h average campus speed → 500 m/min
    eta_minutes = max(1, round(distance_meters / 500))

    return {
        "eta_minutes": eta_minutes,
        "distance_meters": round(distance_meters),
    }
