import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppConstants {
  AppConstants._();

  static const int locationShareIntervalSeconds = 5;
  static const int locationDistanceFilterMeters = 5;

  static const LatLng utmCampusCenter = LatLng(1.5592, 103.6375);
  static const double defaultMapZoom = 15.0;
}
