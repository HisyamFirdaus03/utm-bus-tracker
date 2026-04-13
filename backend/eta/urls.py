from django.urls import path

from eta import views

urlpatterns = [
    path("", views.get_eta, name="eta"),
]
