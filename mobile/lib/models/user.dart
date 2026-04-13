enum UserRole { student, driver, admin }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? matricNumber; // student only
  final String? assignedBusId; // driver only

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.matricNumber,
    this.assignedBusId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.values.byName(json['role'] as String),
      matricNumber: json['matric_number'] as String?,
      assignedBusId: json['assigned_bus_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'matric_number': matricNumber,
        'assigned_bus_id': assignedBusId,
      };
}
