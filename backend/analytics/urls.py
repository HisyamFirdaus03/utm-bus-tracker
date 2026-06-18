from django.urls import path

from analytics import views

urlpatterns = [
    path("overview/", views.overview, name="analytics-overview"),
    path("ridership/daily/", views.ridership_daily, name="analytics-ridership-daily"),
    path("ridership/hourly/", views.ridership_by_hour, name="analytics-ridership-hourly"),
    path("demand/by-stop/", views.demand_by_stop, name="analytics-demand-by-stop"),
    path("feedback/daily/", views.feedback_daily, name="analytics-feedback-daily"),
    path("demand/predict/", views.predict_demand, name="analytics-demand-predict"),
    path("demand/model-status/", views.demand_model_status, name="analytics-demand-status"),
    path("report/", views.report, name="analytics-report"),
]
