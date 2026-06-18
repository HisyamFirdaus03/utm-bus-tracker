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

/// A bus is considered "arrived" when within this many meters of a stop.
/// Sized to a typical bus-stop pull-up area — generous enough that GPS
/// jitter doesn't bounce the UI between "approaching" and "arrived".
const arrivedThresholdMeters = 60.0;

/// True when [bus] is currently parked at [stop] (within
/// [arrivedThresholdMeters]). Returns false when the bus has no live
/// location.
bool isArrivedAtStop(Bus bus, BusStop stop) {
  if (bus.latitude == null || bus.longitude == null) return false;
  return haversineMeters(
        bus.latitude!,
        bus.longitude!,
        stop.latitude,
        stop.longitude,
      ) <=
      arrivedThresholdMeters;
}

/// If the bus has arrived at a stop on [route], returns that stop.
/// Otherwise returns null (the bus is en route).
BusStop? arrivedStop(Bus bus, BusRoute route) {
  final closest = closestStop(bus, route);
  if (closest == null) return null;
  return isArrivedAtStop(bus, closest) ? closest : null;
}

/// Picks the stop the bus is heading to, with driver-input taking priority
/// over GPS-only inference. If the driver has declared a `nextStopId` (set
/// in RTDB by the driver app), and that stop is on [route], we trust it.
/// Otherwise we fall back to [nextStopOnRoute] for the GPS-only guess.
///
/// See backend/DESIGN_CHANGES.md §7 for the rationale.
BusStop? pickNextStop(Bus bus, BusRoute route) {
  final declared = bus.nextStopId;
  if (declared != null) {
    final match = route.stops.where((s) => s.id == declared).firstOrNull;
    if (match != null) return match;
  }
  return nextStopOnRoute(bus, route);
}

/// Returns the next stop in route order after [current]. For circular
/// routes (first ≈ last within 300m), wraps from the last stop to the
/// first. Returns null when [current] is the last stop of a non-circular
/// route. Used by the driver app's auto-advance.
BusStop? advanceStop(BusStop current, BusRoute route) {
  if (route.stops.isEmpty) return null;
  final ordered = [...route.stops]..sort((a, b) => a.order.compareTo(b.order));
  final idx = ordered.indexWhere((s) => s.id == current.id);
  if (idx < 0) return null;
  if (idx < ordered.length - 1) return ordered[idx + 1];
  // Last stop — wrap if the route is roughly circular.
  final circular = haversineMeters(
        ordered.first.latitude,
        ordered.first.longitude,
        ordered.last.latitude,
        ordered.last.longitude,
      ) <
      300;
  return circular ? ordered.first : null;
}

/// Stop on [route] geographically closest to the bus's current position.
///
/// Does **not** model direction of travel — a bus that has just passed a stop
/// will still report that stop as "closest". For "where is the bus heading
/// next", use [nextStopOnRoute] instead. Kept around for cases that genuinely
/// want geographic proximity (e.g., picking the user's nearest stop).
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

/// Stop on [route] the bus is currently heading **toward**, based on
/// projecting the bus's position onto the route's stop polyline and
/// returning the end-stop of the segment the bus is on.
///
/// Why this beats [closestStop]:
/// - A bus sitting at stop N has "closest" = N, but is heading to N+1.
/// - A bus past every stop on a non-circular route still reports the
///   geographically nearest one as next (best we can do without history).
/// - For circular routes (first ≈ last stop within 300m) the wrap segment
///   is included, so a bus past the last stop heads back to the first.
///
/// Implementation: flat-Earth projection in a local-meters frame centred on
/// the bus. For each consecutive (stop_i, stop_{i+1}) segment, project the
/// bus and pick the segment with the smallest perpendicular distance. On a
/// tie (bus exactly at a stop), prefer the segment that **starts** there —
/// the bus is leaving toward the next stop, not arriving at the current one.
BusStop? nextStopOnRoute(Bus bus, BusRoute route) {
  if (bus.latitude == null || bus.longitude == null) return null;
  if (route.stops.isEmpty) return null;

  final ordered = [...route.stops]..sort((a, b) => a.order.compareTo(b.order));
  if (ordered.length == 1) return ordered.first;

  // Local-meters frame centred on the bus. Flat-Earth is fine for campus
  // scale (UTM Skudai is < 3 km across).
  final originLat = bus.latitude!;
  final originLng = bus.longitude!;
  const metersPerDegLat = 111320.0;
  final metersPerDegLng = 111320.0 * math.cos(_toRadians(originLat));

  double xFor(double lng) => (lng - originLng) * metersPerDegLng;
  double yFor(double lat) => (lat - originLat) * metersPerDegLat;

  // Treat the route as circular if its endpoints meet — otherwise a bus
  // past the last stop would have no "ahead" segment to project onto.
  final isCircular = haversineMeters(
        ordered.first.latitude,
        ordered.first.longitude,
        ordered.last.latitude,
        ordered.last.longitude,
      ) <
      300; // 300 m heuristic

  // Segments as (startIndex, endIndex) pairs in `ordered`.
  final segments = <List<int>>[
    for (var i = 0; i < ordered.length - 1; i++) [i, i + 1],
    if (isCircular) [ordered.length - 1, 0],
  ];

  double bestDist = double.infinity;
  double bestT = double.infinity;
  int bestEndIdx = 0;
  const tieEpsilonMeters = 1.0;

  for (final seg in segments) {
    final start = ordered[seg[0]];
    final end = ordered[seg[1]];
    final ax = xFor(start.longitude);
    final ay = yFor(start.latitude);
    final bx = xFor(end.longitude);
    final by = yFor(end.latitude);
    final vx = bx - ax;
    final vy = by - ay;
    final lenSq = vx * vx + vy * vy;
    if (lenSq < 1e-6) continue; // skip degenerate segments

    // Bus is at (0,0), so w = bus − a = −a.
    final t = ((-ax * vx + -ay * vy) / lenSq).clamp(0.0, 1.0);
    final projX = ax + t * vx;
    final projY = ay + t * vy;
    final dist = math.sqrt(projX * projX + projY * projY);

    final betterByDist = dist < bestDist - tieEpsilonMeters;
    final tieAndStartsHere =
        (dist - bestDist).abs() <= tieEpsilonMeters && t < bestT;
    if (betterByDist || tieAndStartsHere) {
      bestDist = dist;
      bestT = t;
      bestEndIdx = seg[1];
    }
  }

  return ordered[bestEndIdx];
}
