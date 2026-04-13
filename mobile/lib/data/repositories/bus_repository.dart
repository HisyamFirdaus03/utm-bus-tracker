import '../../models/models.dart';

abstract class BusRepository {
  Future<List<Bus>> getAllBuses();
  Future<Bus?> getBusById(String id);
  Stream<List<Bus>> watchActiveBuses();
  Future<void> updateBusLocation({
    required String busId,
    required double latitude,
    required double longitude,
    double? speed,
  });

  /// Returns estimated time of arrival in minutes for a given bus.
  Future<int?> getEta(String busId);
}
