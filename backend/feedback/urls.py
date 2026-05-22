from django.urls import path

from feedback import views

urlpatterns = [
    path("", views.feedback_root, name="feedback-root"),
    path("all/", views.feedback_list_all, name="feedback-list-all"),
    path("<str:feedback_id>/respond/", views.feedback_respond, name="feedback-respond"),
]
