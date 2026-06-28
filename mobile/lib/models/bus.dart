enum BusStatus { active, inactive, maintenance }

class Bus {
  final String id;
  final String plateNumber;
  final String routeId;
  final BusStatus status;
  final int capacity;
  // The single source of truth for the driver↔bus relationship per SDD
  // §5.5.2 and DESIGN_CHANGES.md §15. To find "this driver's bus", the
  // mobile driver app filters this list by `driverId == myUid`.
  final String? driverId;
  final double? latitude;
  final double? longitude;
  final double? speed;
  final DateTime? lastUpdated;
  // Driver-declared "next stop I'm heading to", set in RTDB by the driver
  // app. When present and valid, student-side code prefers this over the
  // GPS-inferred next stop. See backend/DESIGN_CHANGES.md §7.
  final String? nextStopId;

  const Bus({
    required this.id,
    required this.plateNumber,
    required this.routeId,
    required this.status,
    required this.capacity,
    this.driverId,
    this.latitude,
    this.longitude,
    this.speed,
    this.lastUpdated,
    this.nextStopId,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'] as String,
      plateNumber: json['plate_number'] as String,
      routeId: json['route_id'] as String,
      status: BusStatus.values.byName(json['status'] as String),
      capacity: json['capacity'] as int,
      driverId: json['driver_id'] as String?,
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
        'driver_id': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'last_updated': lastUpdated?.toIso8601String(),
        'next_stop_id': nextStopId,
      };

  Bus copyWith({
    double? latitude,
    double? longitude,
    double? speed,
    BusStatus? status,
    DateTime? lastUpdated,
    String? nextStopId,
  }) {
    return Bus(
      id: id,
      plateNumber: plateNumber,
      routeId: routeId,
      status: status ?? this.status,
      capacity: capacity,
      driverId: driverId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      nextStopId: nextStopId ?? this.nextStopId,
    );
  }
}
