from rest_framework import serializers


class ScheduleSerializer(serializers.Serializer):
    """Embedded schedule within a BusRoute."""
    departure_time = serializers.CharField()  # e.g. "07:00"
    arrival_time = serializers.CharField()    # e.g. "22:00"
    frequencies = serializers.IntegerField(min_value=1)  # minutes between buses


class BusStopSerializer(serializers.Serializer):
    """Read/write serializer for BusStop — matches Flutter BusStop model."""
    id = serializers.CharField(read_only=True)
    name = serializers.CharField(max_length=100)
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    order = serializers.IntegerField(min_value=0)
    demand = serializers.IntegerField(default=0, required=False)


class BusRouteSerializer(serializers.Serializer):
    """Read/write serializer for BusRoute — matches Flutter BusRoute model."""
    id = serializers.CharField(read_only=True)
    name = serializers.CharField(max_length=100)
    description = serializers.CharField(allow_blank=True, default="")
    color = serializers.CharField(max_length=7, default="#D42A2A")  # hex
    is_active = serializers.BooleanField(default=True)
    stop_ids = serializers.ListField(
        child=serializers.CharField(),
        required=False,
        write_only=True,
    )
    # Nested — populated on read
    stops = BusStopSerializer(many=True, read_only=True)
    schedule = ScheduleSerializer(required=False, allow_null=True)


class BusRouteCreateSerializer(serializers.Serializer):
    """Write serializer for creating/updating a BusRoute."""
    name = serializers.CharField(max_length=100)
    description = serializers.CharField(allow_blank=True, default="")
    color = serializers.CharField(max_length=7, default="#D42A2A")
    is_active = serializers.BooleanField(default=True)
    stop_ids = serializers.ListField(child=serializers.CharField())
    schedule = ScheduleSerializer(required=False, allow_null=True)
