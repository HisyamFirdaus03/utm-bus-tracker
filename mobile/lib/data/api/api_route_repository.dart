import '../../core/api_client.dart';
import '../../models/models.dart';
import '../repositories/route_repository.dart';

class ApiRouteRepository implements RouteRepository {
  @override
  Future<List<BusRoute>> getAllRoutes() async {
    final response = await ApiClient.instance.dio.get('/api/routes/');
    final list = response.data as List;
    return list
        .map((e) => BusRoute.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<BusRoute?> getRouteById(String id) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/routes/$id/');
      return BusRoute.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BusStop>> getStopsForRoute(String routeId) async {
    final route = await getRouteById(routeId);
    return route?.stops ?? [];
  }
}
