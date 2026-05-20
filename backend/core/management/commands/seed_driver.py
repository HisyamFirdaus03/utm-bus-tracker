"""
Management command to create/update a driver account end-to-end.

Creates a Firebase Auth user (or looks up existing), sets the `role=driver`
custom claim, writes the Firestore user doc, and links bus ↔ driver in both
directions. Idempotent — safe to re-run.

Usage:
    python manage.py seed_driver \\
        --email driver1@utm.my \\
        --password driver123 \\
        --name "Test Driver" \\
        --bus-id <firestore_bus_id>
"""

from django.core.management.base import BaseCommand, CommandError
from firebase_admin import auth as firebase_auth

from core.firebase import get_db


class Command(BaseCommand):
    help = "Create a driver account, set role claim, and link to a bus."

    def add_arguments(self, parser):
        parser.add_argument("--email", required=True)
        parser.add_argument("--password", required=True)
        parser.add_argument("--name", required=True)
        parser.add_argument("--bus-id", required=True, dest="bus_id")
        parser.add_argument("--phone", default="")

    def handle(self, *args, **options):
        db = get_db()
        email = options["email"]
        bus_id = options["bus_id"]

        bus_ref = db.collection("buses").document(bus_id)
        if not bus_ref.get().exists:
            raise CommandError(f"Bus {bus_id} not found in Firestore.")

        try:
            user = firebase_auth.get_user_by_email(email)
            self.stdout.write(f"  Found existing user: {user.uid}")
        except firebase_auth.UserNotFoundError:
            user = firebase_auth.create_user(
                email=email,
                password=options["password"],
                display_name=options["name"],
            )
            self.stdout.write(self.style.SUCCESS(f"  Created user: {user.uid}"))

        firebase_auth.set_custom_user_claims(user.uid, {"role": "driver"})
        self.stdout.write("  Set custom claim: role=driver")

        profile = {
            "name": options["name"],
            "email": email,
            "role": "driver",
            "phone_no": options["phone"],
            "assigned_bus_id": bus_id,
        }
        db.collection("users").document(user.uid).set(profile, merge=True)
        self.stdout.write(f"  Wrote users/{user.uid}")

        bus_ref.update({"driver_id": user.uid})
        self.stdout.write(f"  Linked buses/{bus_id}.driver_id → {user.uid}")

        self.stdout.write(self.style.SUCCESS(
            f"\nDriver ready. Login: {email} / {options['password']}"
        ))
