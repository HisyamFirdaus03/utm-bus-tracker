from datetime import datetime

from django.http import HttpResponse
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from analytics import demand_model
from analytics import report as report_builder
from analytics import services


def _admin_required(request):
    if request.user.role != "admin":
        return Response(
            {"detail": "Admin access required."},
            status=status.HTTP_403_FORBIDDEN,
        )
    return None


@api_view(["GET"])
def overview(request):
    deny = _admin_required(request)
    if deny:
        return deny
    return Response(services.overview())


@api_view(["GET"])
def ridership_daily(request):
    deny = _admin_required(request)
    if deny:
        return deny
    days = int(request.query_params.get("days", 30))
    return Response(services.ridership_daily(days))


@api_view(["GET"])
def ridership_by_hour(request):
    deny = _admin_required(request)
    if deny:
        return deny
    return Response(services.ridership_by_hour())


@api_view(["GET"])
def demand_by_stop(request):
    deny = _admin_required(request)
    if deny:
        return deny
    limit = int(request.query_params.get("limit", 10))
    return Response(services.demand_by_stop(limit))


@api_view(["GET"])
def feedback_daily(request):
    deny = _admin_required(request)
    if deny:
        return deny
    days = int(request.query_params.get("days", 30))
    return Response(services.feedback_daily(days))


@api_view(["GET"])
def predict_demand(request):
    """UC07 — Optimize Bus Distribution.

    Query params:
        date    YYYY-MM-DD (default: today)
        hour    0..23     (default: current hour)
        weather clear|cloudy|rain (default: clear)
    """
    deny = _admin_required(request)
    if deny:
        return deny

    date_raw = request.query_params.get("date")
    try:
        date = datetime.strptime(date_raw, "%Y-%m-%d") if date_raw else datetime.now()
    except ValueError:
        return Response(
            {"detail": "Invalid `date`. Expected YYYY-MM-DD."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    hour_raw = request.query_params.get("hour")
    try:
        hour = int(hour_raw) if hour_raw is not None else datetime.now().hour
    except ValueError:
        return Response(
            {"detail": "Invalid `hour`. Expected integer 0..23."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not 0 <= hour <= 23:
        return Response(
            {"detail": "`hour` must be between 0 and 23."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    weather = request.query_params.get("weather", "clear")
    return Response(demand_model.predict_demand(date=date, hour=hour, weather=weather))


@api_view(["GET"])
def demand_model_status(request):
    deny = _admin_required(request)
    if deny:
        return deny
    return Response(demand_model.model_status())


@api_view(["GET"])
def cache_status(request):
    deny = _admin_required(request)
    if deny:
        return deny
    return Response(services.cache_status())


@api_view(["POST"])
def cache_clear(request):
    """Drop the analytics cache so the next request re-reads Firestore.
    Useful after running `seed_data_logs` or `train_demand_model`."""
    deny = _admin_required(request)
    if deny:
        return deny
    services.clear_cache()
    return Response({"detail": "Cache cleared."})


@api_view(["GET"])
def report(request):
    """UC09 — Generate Report. Returns a PDF of the analytics dashboard."""
    deny = _admin_required(request)
    if deny:
        return deny
    days = int(request.query_params.get("days", 30))
    pdf_bytes = report_builder.build_report(days=days)
    filename = f"utm-bustracker-report-{datetime.now().strftime('%Y%m%d-%H%M')}.pdf"
    response = HttpResponse(pdf_bytes, content_type="application/pdf")
    response["Content-Disposition"] = f'attachment; filename="{filename}"'
    return response
