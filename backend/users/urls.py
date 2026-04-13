from django.urls import path

from users import views

urlpatterns = [
    path("register/", views.register, name="auth-register"),
    path("me/", views.me, name="auth-me"),
    path("me/update/", views.update_profile, name="auth-update"),
]
