"""
UC07 — Demand prediction and bus distribution optimization.

Implements the `DemandPredictionModel` entity from SDD §5.9.2:
  - features: historicalData (data_logs), weatherCondition, dayOfWeek
  - model: scikit-learn (RandomForestRegressor)
  - predict(): per-stop demand for a given (date, hour, weather)
  - recommend allocation across the available fleet proportional to demand

Training data comes from Firestore `data_logs` (seeded via
`seed_data_logs`). Model is pickled to `MODEL_PATH` and re-loaded on
each request — cheap since the model is small (a few hundred KB).

Why Random Forest:
  - SDD pins scikit-learn but not the specific algorithm; sklearn's
    RandomForestRegressor is the standard tabular-regression default.
  - Handles one-hot encoded categoricals (weather, stop_id, weekday)
    without scaling or further preprocessing.
  - Exposes `feature_importances_` for interpretability in the viva.
  - Robust to default hyperparameters — no tuning required for PSM 2 scope.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import joblib
import numpy as np
from sklearn.ensemble import RandomForestRegressor

from core.firebase import get_db


MODEL_DIR = Path(__file__).resolve().parent / "models"
MODEL_PATH = MODEL_DIR / "demand_rf.joblib"

# Categorical vocabularies — kept stable so encoded vectors line up
# between training and prediction even if Firestore returns rows in a
# different order.
WEATHER_VOCAB = ["clear", "cloudy", "rain"]
WEEKDAYS = list(range(7))  # 0 = Monday … 6 = Sunday


@dataclass
class TrainResult:
    n_samples: int
    n_features: int
    n_stops: int
    train_score: float  # R^2 on the training set


# ---------------------------------------------------------------------
# Feature engineering
# ---------------------------------------------------------------------

def _stop_vocab() -> list[str]:
    """Stable list of stop IDs (sorted). Used as one-hot vocabulary."""
    ids = [d.id for d in get_db().collection("stops").stream()]
    return sorted(ids)


def _one_hot(value, vocab: list) -> list[int]:
    return [1 if value == v else 0 for v in vocab]


def _encode_row(hour: int, weekday: int, weather: str, stop_id: str,
                stop_vocab: list[str]) -> list[float]:
    """Numerical feature vector for one prediction or training row."""
    # Cyclical encoding for hour-of-day so 23:00 is near 00:00.
    hr_sin = np.sin(2 * np.pi * hour / 24.0)
    hr_cos = np.cos(2 * np.pi * hour / 24.0)
    weekday_oh = _one_hot(weekday, WEEKDAYS)
    weather_oh = _one_hot(weather, WEATHER_VOCAB)
    stop_oh = _one_hot(stop_id, stop_vocab)
    return [hr_sin, hr_cos, *weekday_oh, *weather_oh, *stop_oh]


def _parse_ts(ts: str) -> Optional[datetime]:
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None


def _load_training_data(stop_vocab: list[str]) -> tuple[np.ndarray, np.ndarray]:
    """Pull every row from data_logs and return (X, y)."""
    X, y = [], []
    for doc in get_db().collection("data_logs").stream():
        row = doc.to_dict() or {}
        ts = _parse_ts(row.get("timestamp", ""))
        stop_id = row.get("bus_stop_id")
        weather = row.get("weather", "clear")
        students = row.get("number_of_students")
        if ts is None or not stop_id or students is None:
            continue
        if stop_id not in stop_vocab:
            continue  # stop was deleted after the log was written
        if weather not in WEATHER_VOCAB:
            weather = "clear"
        local = ts.astimezone(timezone.utc)
        X.append(_encode_row(local.hour, local.weekday(), weather, stop_id, stop_vocab))
        y.append(int(students))
    return np.array(X, dtype=float), np.array(y, dtype=float)


# ---------------------------------------------------------------------
# Train + persist
# ---------------------------------------------------------------------

def train_model() -> TrainResult:
    stop_vocab = _stop_vocab()
    X, y = _load_training_data(stop_vocab)
    if len(X) == 0:
        raise RuntimeError(
            "No training data in `data_logs`. Run `python manage.py seed_data_logs`."
        )

    model = RandomForestRegressor(
        n_estimators=120,
        max_depth=14,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1,
    )
    model.fit(X, y)
    train_score = float(model.score(X, y))

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(
        {"model": model, "stop_vocab": stop_vocab, "weather_vocab": WEATHER_VOCAB},
        MODEL_PATH,
    )

    return TrainResult(
        n_samples=len(X),
        n_features=X.shape[1] if X.ndim == 2 else 0,
        n_stops=len(stop_vocab),
        train_score=train_score,
    )


# ---------------------------------------------------------------------
# Predict + recommend
# ---------------------------------------------------------------------

def _load_bundle() -> Optional[dict]:
    if not MODEL_PATH.exists():
        return None
    return joblib.load(MODEL_PATH)


def _stop_names() -> dict[str, str]:
    return {
        d.id: (d.to_dict() or {}).get("name", d.id)
        for d in get_db().collection("stops").stream()
    }


def _count_available_buses() -> int:
    """Active buses in the fleet — used as the allocation budget."""
    count = 0
    for d in get_db().collection("buses").stream():
        row = d.to_dict() or {}
        if row.get("status") in ("active", "inactive"):
            count += 1
    return count


def _allocate_fleet(predictions: list[dict], fleet_size: int) -> list[dict]:
    """Distribute `fleet_size` buses across stops proportional to demand.

    Largest-remainder method: integer floor allocation by share, then the
    leftover buses go to the stops with the biggest fractional remainder.
    Guarantees the totals match `fleet_size` exactly (when possible).
    """
    total = sum(p["predicted_riders"] for p in predictions)
    if fleet_size <= 0 or total <= 0:
        return [{**p, "recommended_buses": 0} for p in predictions]

    shares = [(p["predicted_riders"] / total) * fleet_size for p in predictions]
    floors = [int(s) for s in shares]
    remainders = sorted(
        range(len(predictions)), key=lambda i: shares[i] - floors[i], reverse=True,
    )
    leftover = fleet_size - sum(floors)
    for i in range(leftover):
        floors[remainders[i % len(remainders)]] += 1
    return [
        {**p, "recommended_buses": floors[i]} for i, p in enumerate(predictions)
    ]


def predict_demand(date: datetime, hour: int, weather: str) -> dict:
    """Return per-stop predicted demand + recommended bus allocation.

    Falls back to the historical seasonal average if no trained model is
    found — keeps the endpoint usable before someone runs
    `train_demand_model`.
    """
    bundle = _load_bundle()
    stop_names = _stop_names()
    fleet_size = _count_available_buses()
    weekday = date.weekday()
    weather = weather if weather in WEATHER_VOCAB else "clear"

    if bundle is not None:
        model: RandomForestRegressor = bundle["model"]
        stop_vocab: list[str] = bundle["stop_vocab"]
        X = np.array(
            [_encode_row(hour, weekday, weather, sid, stop_vocab) for sid in stop_vocab],
            dtype=float,
        )
        y_pred = model.predict(X)
        predictions = [
            {
                "stop_id": sid,
                "stop_name": stop_names.get(sid, sid),
                "predicted_riders": max(0, round(float(y_pred[i]), 1)),
            }
            for i, sid in enumerate(stop_vocab)
        ]
        source = "ml_random_forest"
    else:
        # Naive seasonal fallback: historical average for (stop, hour, weekday, weather)
        predictions = _seasonal_average(hour, weekday, weather, stop_names)
        source = "seasonal_average_fallback"

    predictions.sort(key=lambda p: p["predicted_riders"], reverse=True)
    predictions = _allocate_fleet(predictions, fleet_size)

    return {
        "source": source,
        "model_trained": bundle is not None,
        "model_file": str(MODEL_PATH) if bundle is not None else None,
        "input": {
            "date": date.strftime("%Y-%m-%d"),
            "hour": hour,
            "weekday": weekday,
            "weather": weather,
        },
        "fleet_size": fleet_size,
        "predictions": predictions,
    }


def _seasonal_average(hour: int, weekday: int, weather: str,
                      stop_names: dict[str, str]) -> list[dict]:
    """Average riders per stop for the matching (hour, weekday, weather).

    Used when the model file is missing. Same shape as the ML path so the
    UI doesn't need to branch.
    """
    totals: dict[str, float] = {}
    counts: dict[str, int] = {}
    for doc in get_db().collection("data_logs").stream():
        row = doc.to_dict() or {}
        ts = _parse_ts(row.get("timestamp", ""))
        stop_id = row.get("bus_stop_id")
        if ts is None or not stop_id:
            continue
        local = ts.astimezone(timezone.utc)
        if local.hour != hour or local.weekday() != weekday:
            continue
        if row.get("weather", "clear") != weather:
            continue
        totals[stop_id] = totals.get(stop_id, 0.0) + float(row.get("number_of_students", 0) or 0)
        counts[stop_id] = counts.get(stop_id, 0) + 1
    return [
        {
            "stop_id": sid,
            "stop_name": stop_names.get(sid, sid),
            "predicted_riders": round(totals[sid] / counts[sid], 1),
        }
        for sid in totals
    ]


def model_status() -> dict:
    """Lightweight status payload for the admin UI."""
    bundle = _load_bundle()
    if bundle is None:
        return {"trained": False, "model_file": None}
    return {
        "trained": True,
        "model_file": str(MODEL_PATH),
        "modified_at": datetime.fromtimestamp(os.path.getmtime(MODEL_PATH)).isoformat(),
        "n_stops": len(bundle["stop_vocab"]),
    }
