import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';

class RoutePreviewScreen extends ConsumerWidget {
  final String routeId;
  final String? startStopId;
  final String? endStopId;

  const RoutePreviewScreen({
    super.key,
    required this.routeId,
    this.startStopId,
    this.endStopId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(allRoutesProvider);
    final activeBusesAsync = ref.watch(activeBusesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Preview'),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (routes) {
          final route = routes.where((r) => r.id == routeId).firstOrNull;
          if (route == null) {
            return const Center(child: Text('Route not found'));
          }
          return _buildContent(
            context,
            route,
            activeBusesAsync.valueOrNull ?? const [],
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    BusRoute route,
    List<Bus> activeBuses,
  ) {
    final segment = _segmentStops(route);
    final routeColor = _parseColor(route.color);
    final busesOnRoute = activeBuses.where((b) => b.routeId == route.id).toList();

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: GoogleMap(
            initialCameraPosition: _initialCamera(segment),
            markers: _buildMarkers(segment, busesOnRoute),
            polylines: {
              Polyline(
                polylineId: PolylineId(route.id),
                color: routeColor,
                width: 5,
                points: segment
                    .map((s) => LatLng(s.latitude, s.longitude))
                    .toList(),
              ),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
        ),
        _RouteHeader(route: route, color: routeColor),
        _BusesOnRouteStrip(
          buses: busesOnRoute,
          destinationStop: segment.isNotEmpty ? segment.last : null,
        ),
        const Divider(height: 1),
        Expanded(
          flex: 3,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: segment.length,
            itemBuilder: (context, i) {
              final stop = segment[i];
              final isFirst = i == 0;
              final isLast = i == segment.length - 1;
              return _StopTile(
                stop: stop,
                isFirst: isFirst,
                isLast: isLast,
                color: routeColor,
              );
            },
          ),
        ),
      ],
    );
  }

  List<BusStop> _segmentStops(BusRoute route) {
    final ordered = [...route.stops]..sort((a, b) => a.order.compareTo(b.order));
    if (startStopId == null || endStopId == null) return ordered;
    final startIdx = ordered.indexWhere((s) => s.id == startStopId);
    final endIdx = ordered.indexWhere((s) => s.id == endStopId);
    if (startIdx < 0 || endIdx < 0 || startIdx >= endIdx) return ordered;
    return ordered.sublist(startIdx, endIdx + 1);
  }

  CameraPosition _initialCamera(List<BusStop> stops) {
    if (stops.isEmpty) {
      return const CameraPosition(target: LatLng(1.5592, 103.6375), zoom: 15);
    }
    final avgLat =
        stops.map((s) => s.latitude).reduce((a, b) => a + b) / stops.length;
    final avgLng =
        stops.map((s) => s.longitude).reduce((a, b) => a + b) / stops.length;
    return CameraPosition(target: LatLng(avgLat, avgLng), zoom: 14.5);
  }

  Set<Marker> _buildMarkers(List<BusStop> stops, List<Bus> buses) {
    final markers = <Marker>{};
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final isFirst = i == 0;
      final isLast = i == stops.length - 1;
      markers.add(
        Marker(
          markerId: MarkerId('stop_${stop.id}'),
          position: LatLng(stop.latitude, stop.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isFirst
                ? BitmapDescriptor.hueGreen
                : isLast
                    ? BitmapDescriptor.hueRed
                    : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: stop.name),
        ),
      );
    }
    for (final bus in buses) {
      if (bus.latitude == null || bus.longitude == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId('bus_${bus.id}'),
          position: LatLng(bus.latitude!, bus.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: bus.plateNumber, snippet: 'Bus'),
        ),
      );
    }
    return markers;
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return Colors.blueGrey;
    return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
  }
}

class _RouteHeader extends StatelessWidget {
  final BusRoute route;
  final Color color;

  const _RouteHeader({required this.route, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(route.name, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  route.description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusesOnRouteStrip extends ConsumerWidget {
  final List<Bus> buses;
  final BusStop? destinationStop;

  const _BusesOnRouteStrip({required this.buses, this.destinationStop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (buses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text(
          'No active buses on this route right now',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus, size: 18, color: primary),
              const SizedBox(width: 6),
              Text(
                '${buses.length} active ${buses.length == 1 ? 'bus' : 'buses'}'
                '${destinationStop != null ? ' → ${destinationStop!.name}' : ''}',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: buses
                .map((b) => _BusEtaChip(bus: b, stop: destinationStop))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _BusEtaChip extends ConsumerWidget {
  final Bus bus;
  final BusStop? stop;

  const _BusEtaChip({required this.bus, required this.stop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final etaAsync = stop != null
        ? ref.watch(busEtaProvider((busId: bus.id, stopId: stop!.id)))
        : const AsyncValue<int?>.data(null);

    final label = etaAsync.when(
      data: (eta) => eta != null ? '$eta min' : '—',
      loading: () => '…',
      error: (_, _) => '—',
    );

    return Chip(
      label: Text(
        '${bus.plateNumber}  •  $label',
        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
      ),
      backgroundColor: theme.colorScheme.primary.withAlpha(20),
      side: BorderSide(color: theme.colorScheme.primary.withAlpha(60)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _StopTile extends StatelessWidget {
  final BusStop stop;
  final bool isFirst;
  final bool isLast;
  final Color color;

  const _StopTile({
    required this.stop,
    required this.isFirst,
    required this.isLast,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isFirst || isLast ? color : Colors.white,
                    border: Border.all(color: color, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 28,
                    color: color,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 12),
              child: Text(
                stop.name,
                style: TextStyle(
                  fontWeight:
                      isFirst || isLast ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
