class BusStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int order;

  const BusStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.order,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'order': order,
      };
}

class RouteSchedule {
  final String departureTime; // "HH:mm" first service of the day
  final String arrivalTime;   // "HH:mm" last service of the day
  final int frequencyMinutes; // minutes between buses

  const RouteSchedule({
    required this.departureTime,
    required this.arrivalTime,
    required this.frequencyMinutes,
  });

  factory RouteSchedule.fromJson(Map<String, dynamic> json) => RouteSchedule(
        departureTime: json['departure_time'] as String,
        arrivalTime: json['arrival_time'] as String,
        frequencyMinutes: (json['frequencies'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'departure_time': departureTime,
        'arrival_time': arrivalTime,
        'frequencies': frequencyMinutes,
      };
}

class BusRoute {
  final String id;
  final String name;
  final String description;
  final String color; // hex color for map polyline
  final List<BusStop> stops;
  final bool isActive;
  final RouteSchedule? schedule;

  const BusRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.stops,
    this.isActive = true,
    this.schedule,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      color: json['color'] as String,
      stops: (json['stops'] as List)
          .map((s) => BusStop.fromJson(s as Map<String, dynamic>))
          .toList(),
      isActive: json['is_active'] as bool? ?? true,
      schedule: json['schedule'] is Map<String, dynamic>
          ? RouteSchedule.fromJson(json['schedule'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color,
        'stops': stops.map((s) => s.toJson()).toList(),
        'is_active': isActive,
        'schedule': schedule?.toJson(),
      };
}
