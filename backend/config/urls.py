from django.urls import include, path

urlpatterns = [
    path("api/auth/", include("users.urls")),
    path("api/buses/", include("buses.urls")),
    path("api/routes/", include("routes.urls")),
    path("api/eta/", include("eta.urls")),
]
