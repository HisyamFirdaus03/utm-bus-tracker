from django.urls import path

from routes import views

urlpatterns = [
    # Stops (must come before <str:route_id> to avoid "stops" matching as a route ID)
    path("stops/", views.stop_list, name="stop-list"),
    path("stops/create/", views.stop_create, name="stop-create"),
    path("stops/<str:stop_id>/", views.stop_detail, name="stop-detail"),
    path("stops/<str:stop_id>/update/", views.stop_update, name="stop-update"),
    path("stops/<str:stop_id>/delete/", views.stop_delete, name="stop-delete"),
    # Routes
    path("", views.route_list, name="route-list"),
    path("create/", views.route_create, name="route-create"),
    path("<str:route_id>/", views.route_detail, name="route-detail"),
    path("<str:route_id>/update/", views.route_update, name="route-update"),
    path("<str:route_id>/delete/", views.route_delete, name="route-delete"),
]
