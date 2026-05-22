"""
ETA service — estimates bus arrival time using Google Distance Matrix API.

Algorithm (from SDD 5.9.2):
1. Accept origin (bus lat/lng) and destination (stop lat/lng) as input.
2. Call Google Distance Matrix API with inputs.
3. Parse API response to retrieve duration.value.
4. Return ETA in minutes.
"""

import logging
from typing import Optional

import requests
from django.conf import settings

from buses.services import get_bus
from core.firebase import get_rtdb
from routes.services import get_stop


logger = logging.getLogger(__name__)

# Anything longer than this on a campus-scale trip is almost certainly a
# Distance Matrix glitch (no road snap, restricted routing, quota oddity).
# Fall back to the straight-line estimate when Google's answer exceeds it.
_MAX_PLAUSIBLE_DURATION_SECONDS = 3600  # 1 hour


def _get_live_location(bus_id: str) -> Optional[dict]:
    """Read the bus's live lat/lng from RTDB (hot path per SDD Decision #3).

    Returns {"latitude": float, "longitude": float} or None when there's no
    live entry. Firestore's lat/lng on the bus doc is metadata-only and may
    be stale or null — RTDB is the source of truth.
    """
    snap = get_rtdb().reference(f"/bus_locations/{bus_id}").get()
    if not isinstance(snap, dict):
        return None
    lat = snap.get("latitude")
    lng = snap.get("longitude")
    if lat is None or lng is None:
        return None
    return {"latitude": float(lat), "longitude": float(lng)}


def estimate_eta(bus_id: str, stop_id: str) -> Optional[dict]:
    """
    Calculate ETA in minutes from a bus's current position to a stop.

    Returns {"eta_minutes": int, "distance_meters": int} or None if inputs
    are invalid.
    """
    if not get_bus(bus_id):
        return None

    live = _get_live_location(bus_id)
    if live is None:
        return None

    stop = get_stop(stop_id)
    if not stop:
        return None

    bus = live  # for fallback signature compatibility
    origin = f"{live['latitude']},{live['longitude']}"
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
            logger.warning(
                "Distance Matrix element non-OK for bus %s → stop %s: %s "
                "(top-level status=%s, error=%s)",
                bus_id, stop_id, element.get("status"),
                data.get("status"), data.get("error_message"),
            )
            return _fallback_estimate(bus, stop)
        duration_seconds = element["duration"]["value"]
        distance_meters = element["distance"]["value"]
        if duration_seconds > _MAX_PLAUSIBLE_DURATION_SECONDS:
            # Google occasionally returns absurd durations when one of the
            # points doesn't snap cleanly to a road (e.g. mid-field stop
            # placements). Trust haversine instead.
            logger.warning(
                "Distance Matrix returned implausible duration %ss for bus %s → stop %s "
                "(distance %sm); using fallback.",
                duration_seconds, bus_id, stop_id, distance_meters,
            )
            return _fallback_estimate(bus, stop)
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
