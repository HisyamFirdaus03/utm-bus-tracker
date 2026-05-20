import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/route_filter_chips.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final activeBusesAsync = ref.watch(activeBusesStreamProvider);
    final routesAsync = ref.watch(allRoutesProvider);
    final selectedRoute = ref.watch(selectedRouteProvider);

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
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Hello, ${user?.name ?? 'Student'}!',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          routesAsync.when(
            data: (routes) => RouteFilterChips(
              routes: routes,
              selectedRouteId: selectedRoute,
              onSelected: (routeId) {
                ref.read(selectedRouteProvider.notifier).state = routeId;
              },
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading routes: $e'),
            ),
          ),

          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: AppConstants.utmCampusCenter,
                  zoom: AppConstants.defaultMapZoom,
                ),
                onMapCreated: (controller) => _mapController = controller,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: _buildMarkers(
                  activeBusesAsync.valueOrNull ?? const [],
                  routesAsync.valueOrNull ?? const [],
                  selectedRoute,
                ),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: activeBusesAsync.when(
              data: (buses) {
                final filtered = selectedRoute != null
                    ? buses.where((b) => b.routeId == selectedRoute).toList()
                    : buses;

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No active buses on this route'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => BusCard(
                    bus: filtered[index],
                    routesAsync: routesAsync,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers(
    List<Bus> buses,
    List<BusRoute> routes,
    String? selectedRouteId,
  ) {
    final visible = selectedRouteId != null
        ? buses.where((b) => b.routeId == selectedRouteId)
        : buses;

    return visible
        .where((b) => b.latitude != null && b.longitude != null)
        .map((bus) {
      final routeName = routes
          .where((r) => r.id == bus.routeId)
          .map((r) => r.name)
          .firstOrNull;
      return Marker(
        markerId: MarkerId(bus.id),
        position: LatLng(bus.latitude!, bus.longitude!),
        infoWindow: InfoWindow(
          title: bus.plateNumber,
          snippet: routeName ?? bus.routeId,
        ),
        onTap: () => _showBusDetails(bus, routeName),
      );
    }).toSet();
  }

  void _showBusDetails(Bus bus, String? routeName) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus,
                    color: Theme.of(context).colorScheme.primary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bus.plateNumber,
                          style: Theme.of(context).textTheme.titleLarge),
                      if (routeName != null)
                        Text(routeName,
                            style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.speed,
                '${bus.speed?.toStringAsFixed(1) ?? '—'} km/h'),
            _detailRow(
              Icons.access_time,
              bus.lastUpdated != null
                  ? 'Updated ${_timeAgo(bus.lastUpdated!)}'
                  : 'No recent update',
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 10),
            Text(text),
          ],
        ),
      );

  String _timeAgo(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inSeconds < 60) return '${delta.inSeconds}s ago';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    return '${delta.inHours}h ago';
  }
}
