// ============================================================
// MOCK - Delete this file when integrating with Firebase RTDB
// ============================================================

import 'dart:async';
import 'dart:math';

import '../../models/models.dart';
import '../repositories/bus_repository.dart';
import 'mock_data.dart';

class MockBusRepository implements BusRepository {
  late List<Bus> _buses;
  final _controller = StreamController<List<Bus>>.broadcast();
  Timer? _simulationTimer;

  MockBusRepository() {
    _buses = List.from(MockData.buses);
    _startSimulation();
  }

  /// Simulates bus movement by slightly shifting coordinates
  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final random = Random();
      _buses = _buses.map((bus) {
        if (bus.status != BusStatus.active ||
            bus.latitude == null ||
            bus.longitude == null) {
          return bus;
        }
        return bus.copyWith(
          latitude: bus.latitude! + (random.nextDouble() - 0.5) * 0.0005,
          longitude: bus.longitude! + (random.nextDouble() - 0.5) * 0.0005,
          speed: 15.0 + random.nextDouble() * 25.0,
          lastUpdated: DateTime.now(),
        );
      }).toList();
      _controller.add(_buses);
    });
  }

  @override
  Future<List<Bus>> getAllBuses() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_buses);
  }

  @override
  Future<Bus?> getBusById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _buses.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Bus>> watchActiveBuses() {
    // Emit current state immediately, then stream updates
    return _controller.stream.map(
      (buses) => buses.where((b) => b.status == BusStatus.active).toList(),
    ).asBroadcastStream();
  }

  @override
  Future<void> updateBusLocation({
    required String busId,
    required double latitude,
    required double longitude,
    double? speed,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _buses = _buses.map((bus) {
      if (bus.id == busId) {
        return bus.copyWith(
          latitude: latitude,
          longitude: longitude,
          speed: speed,
          lastUpdated: DateTime.now(),
        );
      }
      return bus;
    }).toList();
    _controller.add(_buses);
  }

  @override
  Future<int?> getEta(String busId) async {
    final bus = _buses.where((b) => b.id == busId).firstOrNull;
    if (bus == null || bus.status != BusStatus.active) return null;
    // Mock ETA: deterministic per bus, 3–17 minutes
    final hash = busId.hashCode.abs();
    return 3 + (hash % 15);
  }

  void dispose() {
    _simulationTimer?.cancel();
    _controller.close();
  }
}
