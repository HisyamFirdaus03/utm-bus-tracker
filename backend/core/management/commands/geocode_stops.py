"""
Geocode each stop's lat/lng from its name using Google Geocoding API,
biased to the UTM Skudai campus bounding box.

The original seed coordinates are hand-typed approximations that don't
match the real-world buildings — running this replaces them with actual
positions so polylines, ETAs, and bus marker placements all reflect
UTM geography.

Usage:
    python manage.py geocode_stops              # geocode all, write to Firestore
    python manage.py geocode_stops --dry-run    # preview without writing

After it finishes, re-run `simulate_driver` so the test bus is placed
near the corrected coords.
"""

from typing import Optional

import requests
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from core.firebase import get_db


# Loose UTM Skudai bounding box — biases (but does not restrict) results.
# south-west | north-east, in `lat,lng|lat,lng` form.
UTM_BOUNDS = "1.5500,103.6200|1.5700,103.6600"


class Command(BaseCommand):
    help = "Geocode stop names to real coordinates and update Firestore."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Show planned changes without writing to Firestore.",
        )

    def handle(self, *args, **opts):
        api_key = settings.GOOGLE_MAPS_API_KEY
        if not api_key:
            raise CommandError("GOOGLE_MAPS_API_KEY is not set in backend/.env")

        db = get_db()
        docs = list(db.collection("stops").stream())
        if not docs:
            self.stdout.write("No stops in Firestore. Run `seed_data` first.")
            return

        changed = unchanged = failed = 0
        for doc in docs:
            data = doc.to_dict() or {}
            name = data.get("name", "").strip()
            if not name:
                continue

            # Add a location hint to disambiguate (e.g. "Kolej Tun Razak"
            # exists at several Malaysian campuses).
            query = f"{name}, Universiti Teknologi Malaysia, Skudai, Johor"
            result = self._geocode(query, api_key)
            if result is None:
                self.stderr.write(self.style.WARNING(f"  ✗ {name}: no result"))
                failed += 1
                continue

            new_lat, new_lng = result
            old_lat = data.get("latitude")
            old_lng = data.get("longitude")
            same = (
                old_lat is not None
                and old_lng is not None
                and abs(old_lat - new_lat) < 1e-5
                and abs(old_lng - new_lng) < 1e-5
            )
            if same:
                self.stdout.write(f"  · {name}: unchanged ({new_lat:.5f}, {new_lng:.5f})")
                unchanged += 1
                continue

            old_str = (
                f"({old_lat:.5f}, {old_lng:.5f})"
                if old_lat is not None and old_lng is not None
                else "(unset)"
            )
            self.stdout.write(
                f"  ✓ {name}: {old_str} → ({new_lat:.5f}, {new_lng:.5f})"
            )
            if not opts["dry_run"]:
                db.collection("stops").document(doc.id).update({
                    "latitude": new_lat,
                    "longitude": new_lng,
                })
            changed += 1

        verb = "Would update" if opts["dry_run"] else "Updated"
        self.stdout.write(self.style.SUCCESS(
            f"\n{verb} {changed} stop(s), {unchanged} unchanged, {failed} failed."
        ))
        if opts["dry_run"]:
            self.stdout.write(
                "Dry run — pass without --dry-run to write the changes."
            )

    def _geocode(self, query: str, api_key: str) -> Optional[tuple]:
        try:
            resp = requests.get(
                "https://maps.googleapis.com/maps/api/geocode/json",
                params={
                    "address": query,
                    "bounds": UTM_BOUNDS,
                    "region": "my",
                    "key": api_key,
                },
                timeout=10,
            )
            data = resp.json()
            if data.get("status") != "OK":
                self.stderr.write(
                    f"    Geocoding API: {data.get('status')} "
                    f"{data.get('error_message', '')}"
                )
                return None
            results = data.get("results", [])
            if not results:
                return None
            location = results[0]["geometry"]["location"]
            return float(location["lat"]), float(location["lng"])
        except (requests.RequestException, KeyError, IndexError, ValueError) as e:
            self.stderr.write(f"    Request failed: {e}")
            return None
