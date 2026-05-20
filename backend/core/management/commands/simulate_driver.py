"""
Simulate a driver heartbeat by writing a single RTDB `/bus_locations/{busId}`
entry near a chosen stop, with a fresh server timestamp.

Useful for testing student-side features (UC10 notifications, UC01 markers,
UC03 ETA display) without standing up a live driver app.

Usage:
    # Default: pick the first bus on Route A, place it near its first stop
    python manage.py simulate_driver

    # Pick a specific bus + stop by name
    python manage.py simulate_driver --plate "JQR 5678" --stop "Fakulti Komputeran"

    # Offset the bus ~200m from the stop so ETA isn't 0 right away
    python manage.py simulate_driver --plate "JQR 5678" --offset-meters 200
"""

import time

from django.core.management.base import BaseCommand, CommandError

from core.firebase import get_db, get_rtdb


METERS_PER_DEG_LAT = 111_320.0


class Command(BaseCommand):
    help = "Write a fake live location for a bus into RTDB /bus_locations/."

    def add_arguments(self, parser):
        parser.add_argument("--plate", default=None,
                            help="Plate number (e.g. 'JQR 5678'). Default: first bus.")
        parser.add_argument("--stop", default=None,
                            help="Stop name. Default: first stop on the bus's route.")
        parser.add_argument("--offset-meters", type=float, default=0.0,
                            help="Place the bus this many meters north of the stop.")
        parser.add_argument("--speed", type=float, default=20.0,
                            help="Speed in km/h to report (default 20).")

    def handle(self, *args, **opts):
        db = get_db()
        rtdb = get_rtdb()

        # 1. Find the bus
        buses_query = db.collection("buses")
        if opts["plate"]:
            buses_query = buses_query.where("plate_number", "==", opts["plate"])
        bus_doc = next(iter(buses_query.limit(1).stream()), None)
        if bus_doc is None:
            raise CommandError(
                f"No bus found{' for plate ' + opts['plate'] if opts['plate'] else ''}.")
        bus = bus_doc.to_dict()
        bus_id = bus_doc.id

        # 2. Find the route + stop. Routes store `stop_ids` referencing the
        # top-level `stops` collection; hydrate them here (mirrors what
        # routes/services.py:_populate_stops does for the REST API).
        route_doc = db.collection("routes").document(bus["route_id"]).get()
        if not route_doc.exists:
            raise CommandError(f"Route {bus['route_id']} not found for bus {bus_id}.")
        stop_ids = route_doc.to_dict().get("stop_ids", [])
        if not stop_ids:
            raise CommandError(f"Route {bus['route_id']} has no stop_ids.")
        stops = []
        for sid in stop_ids:
            s_doc = db.collection("stops").document(sid).get()
            if s_doc.exists:
                s = s_doc.to_dict()
                s["id"] = sid
                stops.append(s)
        stops.sort(key=lambda s: s.get("order", 0))
        if not stops:
            raise CommandError(f"Route {bus['route_id']} stop_ids point to no existing stops.")
        if opts["stop"]:
            stop = next((s for s in stops if s["name"] == opts["stop"]), None)
            if stop is None:
                names = ", ".join(s["name"] for s in stops)
                raise CommandError(f"Stop '{opts['stop']}' not on this route. Options: {names}")
        else:
            stop = stops[0]

        # 3. Compute the bus's lat/lng (optionally offset)
        offset_deg = opts["offset_meters"] / METERS_PER_DEG_LAT
        latitude = float(stop["latitude"]) + offset_deg
        longitude = float(stop["longitude"])

        # 4. Write to RTDB
        ref = rtdb.reference(f"/bus_locations/{bus_id}")
        payload = {
            "latitude": latitude,
            "longitude": longitude,
            "speed": float(opts["speed"]),
            "timestamp": int(time.time() * 1000),
            "driver_uid": "simulator",
        }
        ref.set(payload)

        self.stdout.write(self.style.SUCCESS(
            f"Wrote {bus['plate_number']} ({bus_id}) → "
            f"near '{stop['name']}' "
            f"({latitude:.5f}, {longitude:.5f}) at speed {opts['speed']} km/h."
        ))
