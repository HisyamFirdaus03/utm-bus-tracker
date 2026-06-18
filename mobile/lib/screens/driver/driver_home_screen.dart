import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants.dart';
import '../../core/geo.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  String? _errorMessage;
  bool _starting = false;
  String? _selectedNextStopId;

  bool get _isSharing => _positionSub != null;

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleSharing(String busId, BusRoute? route) async {
    if (_isSharing) {
      await _positionSub?.cancel();
      setState(() {
        _positionSub = null;
        _lastPosition = null;
        _errorMessage = null;
      });
      return;
    }

    if (_selectedNextStopId == null) {
      setState(() => _errorMessage =
          'Please pick the next stop before starting location sharing.');
      return;
    }

    setState(() {
      _starting = true;
      _errorMessage = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location services are disabled. Enable GPS and try again.';
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        throw 'Location permission denied.';
      }
      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        await _showPermissionDeniedDialog();
        throw 'Location permission permanently denied.';
      }

      final repo = ref.read(busRepositoryProvider);
      final sub = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: AppConstants.locationDistanceFilterMeters,
        ),
      ).listen(
        (position) async {
          setState(() => _lastPosition = position);
          // Auto-advance: if we've crossed the geofence of our declared
          // next stop, bump to the stop after it in route order.
          final advancedId = _maybeAdvanceNextStop(position, route);
          if (advancedId != null && advancedId != _selectedNextStopId) {
            setState(() => _selectedNextStopId = advancedId);
          }
          try {
            await repo.updateBusLocation(
              busId: busId,
              latitude: position.latitude,
              longitude: position.longitude,
              speed: position.speed * 3.6, // m/s → km/h
              nextStopId: _selectedNextStopId,
            );
          } catch (e) {
            if (mounted) setState(() => _errorMessage = 'Upload failed: $e');
          }
        },
        onError: (Object e) {
          if (mounted) setState(() => _errorMessage = 'GPS error: $e');
        },
      );

      setState(() {
        _positionSub = sub;
        _starting = false;
      });
    } catch (e) {
      setState(() {
        _starting = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Returns the stop ID we should advance to, or null if no advance.
  String? _maybeAdvanceNextStop(Position position, BusRoute? route) {
    if (route == null) return null;
    final currentNext = route.stops
        .where((s) => s.id == _selectedNextStopId)
        .firstOrNull;
    if (currentNext == null) return null;
    final distance = haversineMeters(
      position.latitude,
      position.longitude,
      currentNext.latitude,
      currentNext.longitude,
    );
    if (distance > arrivedThresholdMeters) return null;
    final next = advanceStop(currentNext, route);
    return next?.id;
  }

  Future<void> _showPermissionDeniedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location permission needed'),
        content: const Text(
          'Location access is permanently denied. Open system settings to grant permission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final busesAsync = ref.watch(allBusesProvider);
    final routesAsync = ref.watch(allRoutesProvider);

    final assignedBusId = user?.assignedBusId;
    final assignedBus = assignedBusId == null
        ? null
        : busesAsync.valueOrNull
            ?.where((b) => b.id == assignedBusId)
            .firstOrNull;
    final assignedRoute = assignedBus == null
        ? null
        : routesAsync.valueOrNull
            ?.where((r) => r.id == assignedBus.routeId)
            .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'UTM',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'UTM BusTracker',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _positionSub?.cancel();
              if (!context.mounted) return;
              ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDriverCard(user, assignedBus),
            const SizedBox(height: 16),
            Text(
              'Assigned Route',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _buildRouteSection(routesAsync, busesAsync, assignedRoute),
            if (assignedRoute != null) ...[
              const SizedBox(height: 16),
              _buildNextStopPicker(assignedRoute),
            ],
            const SizedBox(height: 16),
            if (_isSharing) _buildLiveStatusCard(assignedRoute),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (assignedBusId == null || _starting)
                    ? null
                    : () => _toggleSharing(assignedBusId, assignedRoute),
                icon: _starting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_isSharing ? Icons.location_off : Icons.location_on),
                label: Text(
                  _isSharing
                      ? 'Stop Sharing Location'
                      : 'Start Sharing Location',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSharing
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (assignedBusId == null) ...[
              const SizedBox(height: 8),
              Text(
                'No bus assigned. Contact admin to get a bus assignment.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNextStopPicker(BusRoute route) {
    final ordered = [...route.stops]
      ..sort((a, b) => a.order.compareTo(b.order));
    final current = ordered.where((s) => s.id == _selectedNextStopId).firstOrNull;
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: Colors.amber[800], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Next stop',
                  style: TextStyle(
                    color: Colors.amber[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isSharing)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Auto-advancing',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedNextStopId,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.white,
              ),
              hint: const Text('Select the stop you are heading to'),
              items: ordered
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          '${s.order}. ${s.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                setState(() => _selectedNextStopId = id);
              },
            ),
            const SizedBox(height: 8),
            Text(
              current == null
                  ? 'Pick the upcoming stop before you start. The app will auto-advance through stops as you cross each one.'
                  : 'Heading to ${current.name}. Auto-advances on geofence cross (~60 m).',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(AppUser? user, Bus? assignedBus) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withAlpha(30),
              child: Icon(
                Icons.person,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Driver',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    assignedBus != null
                        ? 'Bus: ${assignedBus.plateNumber}'
                        : 'Bus: ${user?.assignedBusId ?? 'Not assigned'}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSection(
    AsyncValue<List<BusRoute>> routesAsync,
    AsyncValue<List<Bus>> busesAsync,
    BusRoute? route,
  ) {
    if (routesAsync.isLoading || busesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (routesAsync.hasError) {
      return Text('Error loading routes: ${routesAsync.error}');
    }
    if (busesAsync.hasError) {
      return Text('Error loading buses: ${busesAsync.error}');
    }
    if (route == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No route assigned'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _hexToColor(route.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  route.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              route.description,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Text(
              'Stops: ${route.stops.length}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            ...route.stops.map(
              (stop) => Padding(
                padding: const EdgeInsets.only(left: 20, top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stop.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatusCard(BusRoute? route) {
    final pos = _lastPosition;
    final currentNext = route?.stops
        .where((s) => s.id == _selectedNextStopId)
        .firstOrNull;
    final distanceLine = (pos != null && currentNext != null)
        ? '${haversineMeters(pos.latitude, pos.longitude, currentNext.latitude, currentNext.longitude).toStringAsFixed(0)} m'
        : '—';
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Sharing live location',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pos == null)
              Text(
                'Waiting for first GPS fix...',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              )
            else ...[
              _statusRow('Lat', pos.latitude.toStringAsFixed(6)),
              _statusRow('Lng', pos.longitude.toStringAsFixed(6)),
              _statusRow('Speed', '${(pos.speed * 3.6).toStringAsFixed(1)} km/h'),
              _statusRow('Accuracy', '±${pos.accuracy.toStringAsFixed(1)} m'),
              if (currentNext != null)
                _statusRow('To ${currentNext.name}', distanceLine),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
