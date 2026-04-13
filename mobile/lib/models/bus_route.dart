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

class BusRoute {
  final String id;
  final String name;
  final String description;
  final String color; // hex color for map polyline
  final List<BusStop> stops;
  final bool isActive;

  const BusRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.stops,
    this.isActive = true,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color,
        'stops': stops.map((s) => s.toJson()).toList(),
        'is_active': isActive,
      };
}
