import 'package:flutter/material.dart';

import '../models/models.dart';
import 'app_theme.dart';

/// Maps a [BusRoute] to a brand-aligned route color, overriding the
/// hex string stored on the model. See HANDOFF.md §2 — Route C in the
/// seed data is orange, but the design uses red.
Color colorForRoute(BusRoute? route) {
  if (route == null) return AppTheme.ink400;
  final name = route.name.trim();
  if (name == 'Route A') return AppTheme.routeA;
  if (name == 'Route B') return AppTheme.routeB;
  if (name == 'Route C') return AppTheme.routeC;

  // Fallback: parse the model's hex string.
  var hex = route.color.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.tryParse(hex, radix: 16) ?? AppTheme.ink400.toARGB32());
}

/// Returns the short single-letter label for a route (e.g. "A").
String letterForRoute(BusRoute? route) {
  if (route == null) return '·';
  final name = route.name.trim();
  if (name.startsWith('Route ') && name.length > 6) return name.substring(6, 7);
  return name.isNotEmpty ? name[0] : '·';
}
