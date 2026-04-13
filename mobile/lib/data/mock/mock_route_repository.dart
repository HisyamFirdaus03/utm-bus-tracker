// ============================================================
// MOCK - Delete this file when integrating with Firestore
// ============================================================

import '../../models/models.dart';
import '../repositories/route_repository.dart';
import 'mock_data.dart';

class MockRouteRepository implements RouteRepository {
  @override
  Future<List<BusRoute>> getAllRoutes() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(MockData.routes);
  }

  @override
  Future<BusRoute?> getRouteById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return MockData.routes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BusStop>> getStopsForRoute(String routeId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      final route = MockData.routes.firstWhere((r) => r.id == routeId);
      return List.unmodifiable(route.stops);
    } catch (_) {
      return [];
    }
  }
}
