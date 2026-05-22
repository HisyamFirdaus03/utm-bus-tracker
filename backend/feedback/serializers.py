from rest_framework import serializers


STATUS_CHOICES = ("new", "in_progress", "resolved")


class FeedbackCreateSerializer(serializers.Serializer):
    """Payload accepted on POST /api/feedbacks/."""
    bus_id = serializers.CharField()
    description = serializers.CharField(min_length=1, max_length=2000)
    screenshot_url = serializers.URLField(required=False, allow_null=True, allow_blank=True)


class FeedbackSerializer(serializers.Serializer):
    """Full feedback document — matches Flutter Feedback model."""
    id = serializers.CharField(read_only=True)
    student_id = serializers.CharField(read_only=True)
    bus_id = serializers.CharField()
    description = serializers.CharField()
    screenshot_url = serializers.URLField(required=False, allow_null=True, allow_blank=True)
    status = serializers.ChoiceField(choices=STATUS_CHOICES, default="new")
    admin_response = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    timestamp = serializers.CharField()


class FeedbackRespondSerializer(serializers.Serializer):
    """Payload accepted on PATCH /api/feedbacks/<id>/respond/."""
    admin_response = serializers.CharField(
        required=False, allow_null=True, allow_blank=True, max_length=2000
    )
    status = serializers.ChoiceField(choices=STATUS_CHOICES, required=False)
