import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../repositories/bus_repository.dart';

class ApiBusRepository implements BusRepository {
  final DatabaseReference _rtdbRef =
      FirebaseDatabase.instance.ref('bus_locations');

  @override
  Future<List<Bus>> getAllBuses() async {
    final response = await ApiClient.instance.dio.get('/api/buses/');
    final list = response.data as List;
    return list.map((e) => Bus.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Bus?> getBusById(String id) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/buses/$id/');
      return Bus.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Bus>> watchActiveBuses() async* {
    final metadata = await getAllBuses();

    yield* _rtdbRef.onValue
        .map((event) {
          final snapshot = event.snapshot.value as Map<dynamic, dynamic>?;
          return metadata
              .map((bus) => _mergeLiveLocation(bus, snapshot))
              .where((bus) => bus.status == BusStatus.active)
              .toList();
        })
        // Swallow permission-denied that briefly fires during sign-out before
        // the auth-aware provider tears this stream down. The provider rebuilds
        // on the next auth state so the data path recovers automatically.
        .handleError((Object _) {});
  }

  Bus _mergeLiveLocation(Bus bus, Map<dynamic, dynamic>? snapshot) {
    final loc = snapshot?[bus.id];
    if (loc is! Map) {
      // No live RTDB pulse — bus is not actively tracked. Per SDD Decision #3,
      // RTDB is the source of truth for liveness; ignore stale Firestore
      // lat/lng/speed and surface the bus as inactive.
      return Bus(
        id: bus.id,
        plateNumber: bus.plateNumber,
        routeId: bus.routeId,
        status: BusStatus.inactive,
        capacity: bus.capacity,
      );
    }

    final ts = loc['timestamp'];
    return bus.copyWith(
      latitude: (loc['latitude'] as num?)?.toDouble(),
      longitude: (loc['longitude'] as num?)?.toDouble(),
      speed: (loc['speed'] as num?)?.toDouble(),
      lastUpdated: ts is num
          ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
          : null,
      status: BusStatus.active,
    );
  }

  @override
  Future<void> updateBusLocation({
    required String busId,
    required double latitude,
    required double longitude,
    double? speed,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw ApiException('Must be signed in to share location');
    }
    await _rtdbRef.child(busId).set({
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed ?? 0,
      'timestamp': ServerValue.timestamp,
      'driver_uid': uid,
    });
  }

  @override
  Future<int?> getEta({required String busId, required String stopId}) async {
    try {
      final response = await ApiClient.instance.dio.get(
        '/api/eta/',
        queryParameters: {'bus_id': busId, 'stop_id': stopId},
      );
      final data = response.data as Map<String, dynamic>;
      final eta = data['eta_minutes'];
      return eta is num ? eta.toInt() : null;
    } catch (_) {
      return null;
    }
  }
}
