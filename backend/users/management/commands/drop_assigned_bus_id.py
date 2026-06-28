"""
One-shot migration to drop the deprecated `assigned_bus_id` field from
every driver user document.

Why: prior to this migration, the system kept a denormalized
`users/{driverUid}.assigned_bus_id` field that mirrored
`buses/{busId}.driver_id`. The denormalization required two-way sync and
caused drift bugs (orphan IDs pointing at deleted buses). Per SDD §5.5.2
the driver↔bus relationship is one-sided; we now query `buses` where
`driver_id == uid` instead. This command removes the stale field so the
schema matches the design.

Idempotent — safe to re-run; drivers without the field are skipped.

Usage:
    python manage.py drop_assigned_bus_id
    python manage.py drop_assigned_bus_id --dry-run
"""

from django.core.management.base import BaseCommand
from google.cloud.firestore_v1 import DELETE_FIELD

from core.firebase import get_db


class Command(BaseCommand):
    help = "Drop the deprecated assigned_bus_id field from all driver users."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Report which docs would be updated without writing anything.",
        )

    def handle(self, *args, **options):
        db = get_db()
        dry = options["dry_run"]

        candidates = []
        for doc in db.collection("users").where("role", "==", "driver").stream():
            data = doc.to_dict() or {}
            if "assigned_bus_id" in data:
                candidates.append((doc.id, data.get("name"), data.get("assigned_bus_id")))

        if not candidates:
            self.stdout.write(self.style.SUCCESS(
                "No driver docs carry assigned_bus_id. Nothing to do."
            ))
            return

        for uid, name, stale_value in candidates:
            self.stdout.write(
                f"  {'would clear' if dry else 'clearing'} users/{uid} "
                f"({name}): assigned_bus_id={stale_value!r}"
            )
            if not dry:
                db.collection("users").document(uid).update(
                    {"assigned_bus_id": DELETE_FIELD}
                )

        self.stdout.write(self.style.SUCCESS(
            f"\n{'Would update' if dry else 'Updated'} {len(candidates)} driver docs."
        ))
