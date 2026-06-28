from django.urls import path

from users import views

urlpatterns = [
    path("register/", views.register, name="auth-register"),
    path("me/", views.me, name="auth-me"),
    path("me/update/", views.update_profile, name="auth-update"),
    path("drivers/", views.list_drivers, name="auth-drivers-list"),
    path("drivers/create/", views.create_driver, name="auth-drivers-create"),
    path("drivers/<str:uid>/", views.update_driver, name="auth-drivers-update"),
    path("drivers/<str:uid>/delete/", views.delete_driver, name="auth-drivers-delete"),
]
