"""
Train the UC07 demand-prediction model on the current `data_logs`
collection and persist it to `analytics/models/demand_rf.joblib`.

Usage:
    python manage.py train_demand_model
"""

from django.core.management.base import BaseCommand

from analytics import demand_model


class Command(BaseCommand):
    help = "Train the demand prediction model from Firestore data_logs."

    def handle(self, *args, **options):
        self.stdout.write("Loading data_logs and training Random Forest…")
        result = demand_model.train_model()
        self.stdout.write(self.style.SUCCESS(
            f"Trained on {result.n_samples} samples × {result.n_features} features "
            f"across {result.n_stops} stops. "
            f"R^2 (train) = {result.train_score:.3f}. "
            f"Model saved to {demand_model.MODEL_PATH}."
        ))
