from rest_framework import serializers

ROLE_CHOICES = ("student", "driver", "admin")


class RegisterSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(min_length=6, write_only=True)
    role = serializers.ChoiceField(choices=ROLE_CHOICES, default="student")
    # Student-only
    matric_number = serializers.CharField(max_length=20, required=False)
    faculty = serializers.CharField(max_length=100, required=False)
    year = serializers.IntegerField(required=False)
    # Driver-only
    phone_no = serializers.CharField(max_length=20, required=False)


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField()


class UserSerializer(serializers.Serializer):
    """Read-only serializer for user profile responses."""
    id = serializers.CharField(read_only=True)
    name = serializers.CharField()
    email = serializers.EmailField()
    role = serializers.ChoiceField(choices=ROLE_CHOICES)
    matric_number = serializers.CharField(required=False, allow_null=True)
    faculty = serializers.CharField(required=False, allow_null=True)
    year = serializers.IntegerField(required=False, allow_null=True)
    phone_no = serializers.CharField(required=False, allow_null=True)
    assigned_bus_id = serializers.CharField(required=False, allow_null=True)
