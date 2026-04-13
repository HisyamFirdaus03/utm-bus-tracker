"""
Management command to seed Firestore with UTM bus data.

Usage:
    python manage.py seed_data          # seed all
    python manage.py seed_data --clear  # delete existing data first, then seed
"""

from django.core.management.base import BaseCommand

from core.firebase import get_db


# ── Stop Data ─────────────────────────────────────────────────────

STOPS = [
    # Route A stops
    {"name": "Kolej Rahman Putra", "latitude": 1.5625, "longitude": 103.6472, "order": 1, "demand": 0},
    {"name": "Dewan Sultan Iskandar", "latitude": 1.5607, "longitude": 103.6437, "order": 2, "demand": 0},
    {"name": "Fakulti Komputeran", "latitude": 1.5590, "longitude": 103.6380, "order": 3, "demand": 0},
    {"name": "Perpustakaan Sultanah Zanariah", "latitude": 1.5605, "longitude": 103.6350, "order": 4, "demand": 0},
    {"name": "Arked Meranti", "latitude": 1.5575, "longitude": 103.6365, "order": 5, "demand": 0},
    # Route B stops
    {"name": "Kolej Tun Fatimah", "latitude": 1.5537, "longitude": 103.6425, "order": 1, "demand": 0},
    {"name": "Fakulti Kejuruteraan Elektrik", "latitude": 1.5560, "longitude": 103.6390, "order": 2, "demand": 0},
    {"name": "Fakulti Kejuruteraan Mekanikal", "latitude": 1.5572, "longitude": 103.6355, "order": 3, "demand": 0},
    {"name": "Pusat Kesihatan UTM", "latitude": 1.5600, "longitude": 103.6410, "order": 4, "demand": 0},
    # Route C stops
    {"name": "Kolej Datin Seri Endon", "latitude": 1.5530, "longitude": 103.6460, "order": 1, "demand": 0},
    {"name": "Kolej Tun Razak", "latitude": 1.5555, "longitude": 103.6445, "order": 2, "demand": 0},
    {"name": "Main Gate UTM", "latitude": 1.5635, "longitude": 103.6480, "order": 3, "demand": 0},
]

# Routes reference stops by name — resolved to IDs at seed time
ROUTES = [
    {
        "name": "Route A",
        "description": "Main Campus Loop - Kolej Rahman Putra to Faculty Area",
        "color": "#4CAF50",
        "is_active": True,
        "stop_names": [
            "Kolej Rahman Putra",
            "Dewan Sultan Iskandar",
            "Fakulti Komputeran",
            "Perpustakaan Sultanah Zanariah",
            "Arked Meranti",
        ],
        "schedule": {
            "departure_time": "07:00",
            "arrival_time": "22:00",
            "frequencies": 15,
        },
    },
    {
        "name": "Route B",
        "description": "Kolej Tun Fatimah to Faculty of Engineering",
        "color": "#2196F3",
        "is_active": True,
        "stop_names": [
            "Kolej Tun Fatimah",
            "Fakulti Kejuruteraan Elektrik",
            "Fakulti Kejuruteraan Mekanikal",
            "Pusat Kesihatan UTM",
        ],
        "schedule": {
            "departure_time": "07:30",
            "arrival_time": "21:00",
            "frequencies": 20,
        },
    },
    {
        "name": "Route C",
        "description": "Evening Route - Residential to Main Gate",
        "color": "#FF9800",
        "is_active": True,
        "stop_names": [
            "Kolej Datin Seri Endon",
            "Kolej Tun Razak",
            "Main Gate UTM",
        ],
        "schedule": {
            "departure_time": "17:00",
            "arrival_time": "23:00",
            "frequencies": 25,
        },
    },
]

# Buses reference routes by name — resolved to IDs at seed time
BUSES = [
    {
        "bus_name": "Bus A1",
        "plate_number": "JQR 1234",
        "route_name": "Route A",
        "status": "active",
        "capacity": 40,
        "latitude": 1.5610,
        "longitude": 103.6450,
        "speed": 25.0,
    },
    {
        "bus_name": "Bus A2",
        "plate_number": "JQR 5678",
        "route_name": "Route A",
        "status": "active",
        "capacity": 40,
        "latitude": 1.5585,
        "longitude": 103.6370,
        "speed": 18.0,
    },
    {
        "bus_name": "Bus B1",
        "plate_number": "JQR 9012",
        "route_name": "Route B",
        "status": "active",
        "capacity": 35,
        "latitude": 1.5550,
        "longitude": 103.6400,
        "speed": 30.0,
    },
    {
        "bus_name": "Bus C1",
        "plate_number": "JQR 3456",
        "route_name": "Route C",
        "status": "inactive",
        "capacity": 40,
        "latitude": None,
        "longitude": None,
        "speed": None,
    },
]


class Command(BaseCommand):
    help = "Seed Firestore with UTM bus stops, routes, and buses."

    def add_arguments(self, parser):
        parser.add_argument(
            "--clear",
            action="store_true",
            help="Delete existing stops, routes, and buses before seeding.",
        )

    def handle(self, *args, **options):
        db = get_db()

        if options["clear"]:
            self._clear_collection(db, "stops")
            self._clear_collection(db, "routes")
            self._clear_collection(db, "buses")
            self.stdout.write(self.style.WARNING("Cleared existing data."))

        # 1. Seed stops
        stop_name_to_id = {}
        for stop in STOPS:
            ref = db.collection("stops").document()
            ref.set(stop)
            stop_name_to_id[stop["name"]] = ref.id
            self.stdout.write(f"  + Stop: {stop['name']} ({ref.id})")

        # 2. Seed routes (resolve stop names → IDs)
        route_name_to_id = {}
        for route in ROUTES:
            stop_ids = [stop_name_to_id[name] for name in route["stop_names"]]
            doc = {
                "name": route["name"],
                "description": route["description"],
                "color": route["color"],
                "is_active": route["is_active"],
                "stop_ids": stop_ids,
                "schedule": route["schedule"],
            }
            ref = db.collection("routes").document()
            ref.set(doc)
            route_name_to_id[route["name"]] = ref.id
            self.stdout.write(f"  + Route: {route['name']} ({ref.id}) with {len(stop_ids)} stops")

        # 3. Seed buses (resolve route names → IDs)
        for bus in BUSES:
            doc = {
                "bus_name": bus["bus_name"],
                "plate_number": bus["plate_number"],
                "route_id": route_name_to_id[bus["route_name"]],
                "status": bus["status"],
                "capacity": bus["capacity"],
                "latitude": bus["latitude"],
                "longitude": bus["longitude"],
                "speed": bus["speed"],
                "driver_id": None,
                "last_updated": None,
            }
            ref = db.collection("buses").document()
            ref.set(doc)
            self.stdout.write(f"  + Bus: {bus['bus_name']} ({ref.id})")

        self.stdout.write(self.style.SUCCESS(
            f"\nSeeded {len(STOPS)} stops, {len(ROUTES)} routes, {len(BUSES)} buses."
        ))

    def _clear_collection(self, db, collection_name):
        docs = db.collection(collection_name).stream()
        count = 0
        for doc in docs:
            doc.reference.delete()
            count += 1
        self.stdout.write(f"  Deleted {count} docs from '{collection_name}'")
