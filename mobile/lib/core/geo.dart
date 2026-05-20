import 'dart:math' as math;

import '../models/models.dart';

/// Great-circle distance in meters between two lat/lng points.
double haversineMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadius = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180;

/// Stop on [route] closest to the bus's current position.
/// Returns null if the bus has no live location or the route has no stops.
///
/// Used as a "next stop" proxy for ETA defaults — true next-stop tracking
/// would need visit history we don't have.
BusStop? closestStop(Bus bus, BusRoute route) {
  if (bus.latitude == null || bus.longitude == null) return null;
  if (route.stops.isEmpty) return null;

  BusStop? best;
  double bestDist = double.infinity;
  for (final stop in route.stops) {
    final d = haversineMeters(
      bus.latitude!,
      bus.longitude!,
      stop.latitude,
      stop.longitude,
    );
    if (d < bestDist) {
      bestDist = d;
      best = stop;
    }
  }
  return best;
}
