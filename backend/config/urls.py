from django.http import JsonResponse
from django.urls import include, path


def healthz(_request):
    # Liveness probe for Docker/Coolify. No auth, no Firestore — must stay
    # cheap so the healthcheck doesn't blow the Firestore quota.
    return JsonResponse({"status": "ok"})


urlpatterns = [
    path("healthz/", healthz),
    path("api/auth/", include("users.urls")),
    path("api/buses/", include("buses.urls")),
    path("api/routes/", include("routes.urls")),
    path("api/eta/", include("eta.urls")),
    path("api/feedbacks/", include("feedback.urls")),
    path("api/analytics/", include("analytics.urls")),
]
