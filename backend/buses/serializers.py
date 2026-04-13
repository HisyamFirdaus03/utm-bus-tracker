from rest_framework import serializers

STATUS_CHOICES = ("active", "inactive", "maintenance")


class BusSerializer(serializers.Serializer):
    """Read/write serializer for Bus documents — matches Flutter Bus model."""
    id = serializers.CharField(read_only=True)
    bus_name = serializers.CharField(max_length=100)
    plate_number = serializers.CharField(max_length=20)
    route_id = serializers.CharField()
    status = serializers.ChoiceField(choices=STATUS_CHOICES, default="inactive")
    capacity = serializers.IntegerField(min_value=1)
    driver_id = serializers.CharField(required=False, allow_null=True)
    latitude = serializers.FloatField(required=False, allow_null=True)
    longitude = serializers.FloatField(required=False, allow_null=True)
    speed = serializers.FloatField(required=False, allow_null=True)
    last_updated = serializers.DateTimeField(required=False, allow_null=True)


class UpdateLocationSerializer(serializers.Serializer):
    """Payload sent by the driver app to update bus GPS position."""
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    speed = serializers.FloatField(required=False, default=0.0)
