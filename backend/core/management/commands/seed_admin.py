"""
Management command to create/update an admin account.

Creates a Firebase Auth user (or looks up existing), sets the `role=admin`
custom claim, and writes the Firestore user doc. Idempotent.

Usage:
    python manage.py seed_admin \\
        --email admin@utm.my \\
        --password admin123 \\
        --name "Test Admin"
"""

from django.core.management.base import BaseCommand
from firebase_admin import auth as firebase_auth

from core.firebase import get_db


class Command(BaseCommand):
    help = "Create an admin account and set role=admin custom claim."

    def add_arguments(self, parser):
        parser.add_argument("--email", required=True)
        parser.add_argument("--password", required=True)
        parser.add_argument("--name", required=True)

    def handle(self, *args, **options):
        db = get_db()
        email = options["email"]

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

        firebase_auth.set_custom_user_claims(user.uid, {"role": "admin"})
        self.stdout.write("  Set custom claim: role=admin")

        profile = {
            "name": options["name"],
            "email": email,
            "role": "admin",
        }
        db.collection("users").document(user.uid).set(profile, merge=True)
        self.stdout.write(f"  Wrote users/{user.uid}")

        self.stdout.write(self.style.SUCCESS(
            f"\nAdmin ready. Login: {email} / {options['password']}\n"
            f"NOTE: After role-claim changes, the client must refresh its ID token "
            f"(force token refresh / re-login) before backend writes work."
        ))
