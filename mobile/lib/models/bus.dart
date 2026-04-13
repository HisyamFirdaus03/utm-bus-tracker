enum BusStatus { active, inactive, maintenance }

class Bus {
  final String id;
  final String plateNumber;
  final String routeId;
  final BusStatus status;
  final int capacity;
  final double? latitude;
  final double? longitude;
  final double? speed;
  final DateTime? lastUpdated;

  const Bus({
    required this.id,
    required this.plateNumber,
    required this.routeId,
    required this.status,
    required this.capacity,
    this.latitude,
    this.longitude,
    this.speed,
    this.lastUpdated,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'] as String,
      plateNumber: json['plate_number'] as String,
      routeId: json['route_id'] as String,
      status: BusStatus.values.byName(json['status'] as String),
      capacity: json['capacity'] as int,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plate_number': plateNumber,
        'route_id': routeId,
        'status': status.name,
        'capacity': capacity,
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'last_updated': lastUpdated?.toIso8601String(),
      };

  Bus copyWith({
    double? latitude,
    double? longitude,
    double? speed,
    BusStatus? status,
    DateTime? lastUpdated,
  }) {
    return Bus(
      id: id,
      plateNumber: plateNumber,
      routeId: routeId,
      status: status ?? this.status,
      capacity: capacity,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
