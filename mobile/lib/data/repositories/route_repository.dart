import '../../models/models.dart';

abstract class RouteRepository {
  Future<List<BusRoute>> getAllRoutes();
  Future<BusRoute?> getRouteById(String id);
  Future<List<BusStop>> getStopsForRoute(String routeId);
}
