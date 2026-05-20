import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/api_bus_repository.dart';
import '../data/api/api_route_repository.dart';
import '../data/firebase/firebase_auth_repository.dart';
import '../data/repositories/repositories.dart';
import '../models/models.dart';

// ============================================================
// Repository providers
// ============================================================

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final busRepositoryProvider = Provider<BusRepository>((ref) {
  return ApiBusRepository();
});

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return ApiRouteRepository();
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
  StreamSubscription<User?>? _sub;

  AuthNotifier(this._repo) : super(const AsyncValue.loading()) {
    _sub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChange);
  }

  Future<void> _onAuthChange(User? firebaseUser) async {
    if (firebaseUser == null) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      final user = await _repo.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

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

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? matricNumber,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.register(
        name: name,
        email: email,
        password: password,
        role: role,
        matricNumber: matricNumber,
      );
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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

typedef EtaArgs = ({String busId, String stopId});

final busEtaProvider = FutureProvider.family<int?, EtaArgs>((ref, args) {
  return ref
      .watch(busRepositoryProvider)
      .getEta(busId: args.busId, stopId: args.stopId);
});

// ============================================================
// Route data providers
// ============================================================

final allRoutesProvider = FutureProvider<List<BusRoute>>((ref) {
  return ref.watch(routeRepositoryProvider).getAllRoutes();
});

final selectedRouteProvider = StateProvider<String?>((ref) => null);
