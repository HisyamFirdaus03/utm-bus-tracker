from django.urls import path

from buses import views

urlpatterns = [
    path("", views.bus_list, name="bus-list"),
    path("create/", views.bus_create, name="bus-create"),
    path("<str:bus_id>/", views.bus_detail, name="bus-detail"),
    path("<str:bus_id>/update/", views.bus_update, name="bus-update"),
    path("<str:bus_id>/delete/", views.bus_delete, name="bus-delete"),
    path("<str:bus_id>/location/", views.bus_update_location, name="bus-update-location"),
]
