from django.urls import path

from feedback import views

urlpatterns = [
    path("", views.feedback_root, name="feedback-root"),
]
