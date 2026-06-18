from datetime import datetime

from django.http import HttpResponse
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

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
