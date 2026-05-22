"""
Management command to seed Firestore `data_logs` with synthetic ridership
history. Models a realistic daily curve (morning + afternoon peaks),
weekday lift, weather variation, and per-stop demand weighting.

Usage:
    python manage.py seed_data_logs               # 30 days, all active routes
    python manage.py seed_data_logs --days 60     # 60 days of history
    python manage.py seed_data_logs --clear       # wipe data_logs first
"""

import random
from datetime import datetime, timedelta, timezone

from django.core.management.base import BaseCommand

from core.firebase import get_db


WEATHER = ["clear", "clear", "clear", "cloudy", "cloudy", "rain"]  # weighted

# Hour-of-day demand weights (0..1). 7-9 AM and 4-6 PM peaks.
HOURLY_WEIGHTS = [
    0.0, 0.0, 0.0, 0.0, 0.0, 0.05,
    0.20, 0.85, 1.00, 0.55, 0.35, 0.45,
    0.50, 0.40, 0.40, 0.55, 0.90, 1.00,
    0.70, 0.45, 0.30, 0.20, 0.10, 0.05,
]


class Command(BaseCommand):
    help = "Seed Firestore data_logs with synthetic ridership records."

    def add_arguments(self, parser):
        parser.add_argument("--days", type=int, default=30)
        parser.add_argument("--clear", action="store_true")

    def handle(self, *args, **options):
        db = get_db()
        days = options["days"]

        if options["clear"]:
            self.stdout.write("Clearing data_logs…")
            for doc in db.collection("data_logs").stream():
                doc.reference.delete()

        # Load active buses + stops
        buses = []
        for d in db.collection("buses").stream():
            row = d.to_dict() or {}
            row["id"] = d.id
            buses.append(row)
        stops = []
        for d in db.collection("stops").stream():
            row = d.to_dict() or {}
            row["id"] = d.id
            stops.append(row)

        if not buses or not stops:
            self.stderr.write("No buses or stops found. Run `seed_data` first.")
            return

        active_buses = [b for b in buses if b.get("status") != "maintenance"] or buses

        # Per-stop demand multiplier (give early-order stops more demand)
        def stop_weight(s: dict) -> float:
            order = s.get("order", 1)
            return max(0.4, 1.2 - 0.15 * order)

        now = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
        batch = db.batch()
        batch_size = 0
        total_written = 0

        for day_offset in range(days):
            day = now - timedelta(days=day_offset)
            weekday_lift = 1.0 if day.weekday() < 5 else 0.45  # quieter on weekends
            for hour in range(24):
                base = HOURLY_WEIGHTS[hour] * weekday_lift
                if base <= 0:
                    continue
                weather = random.choices(WEATHER, k=1)[0]
                weather_mult = 0.7 if weather == "rain" else 1.0
                # One log per stop per hour, capped to a few buses for realism
                for stop in stops:
                    if random.random() > base * stop_weight(stop):
                        continue
                    bus = random.choice(active_buses)
                    students = max(
                        0,
                        int(random.gauss(
                            mu=base * 18 * stop_weight(stop) * weather_mult,
                            sigma=4,
                        )),
                    )
                    ts = day.replace(hour=hour, minute=random.randint(0, 59))
                    ref = db.collection("data_logs").document()
                    batch.set(ref, {
                        "timestamp": ts.isoformat(),
                        "weather": weather,
                        "number_of_students": students,
                        "number_of_buses": len(active_buses),
                        "bus_id": bus["id"],
                        "bus_stop_id": stop["id"],
                    })
                    batch_size += 1
                    if batch_size >= 400:
                        batch.commit()
                        total_written += batch_size
                        batch = db.batch()
                        batch_size = 0

        if batch_size:
            batch.commit()
            total_written += batch_size

        self.stdout.write(self.style.SUCCESS(
            f"Wrote {total_written} data_logs across {days} days."
        ))
