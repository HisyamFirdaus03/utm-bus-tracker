import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/mock_auth_repository.dart';
import '../data/mock/mock_bus_repository.dart';
import '../data/mock/mock_route_repository.dart';
import '../data/repositories/repositories.dart';
import '../models/models.dart';

// ============================================================
// Repository providers
// To swap mock → Firebase: replace the mock constructors below
// ============================================================

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

final busRepositoryProvider = Provider<BusRepository>((ref) {
  return MockBusRepository();
});

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return MockRouteRepository();
});

// ============================================================
// Auth state
// ============================================================

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AppUser?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.login(email, password);
      state = AsyncValue.data(user);
      return user != null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncValue.data(null);
  }
}

// ============================================================
// Bus data providers
// ============================================================

final allBusesProvider = FutureProvider<List<Bus>>((ref) {
  return ref.watch(busRepositoryProvider).getAllBuses();
});

final activeBusesStreamProvider = StreamProvider<List<Bus>>((ref) {
  return ref.watch(busRepositoryProvider).watchActiveBuses();
});

final busEtaProvider = FutureProvider.family<int?, String>((ref, busId) {
  return ref.watch(busRepositoryProvider).getEta(busId);
});

// ============================================================
// Route data providers
// ============================================================

final allRoutesProvider = FutureProvider<List<BusRoute>>((ref) {
  return ref.watch(routeRepositoryProvider).getAllRoutes();
});

final selectedRouteProvider = StateProvider<String?>((ref) => null);
