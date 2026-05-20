import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geo.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/watchlist_provider.dart';

class BusDetailsSheet extends ConsumerStatefulWidget {
  final Bus bus;
  final BusRoute? route;

  const BusDetailsSheet({super.key, required this.bus, this.route});

  @override
  ConsumerState<BusDetailsSheet> createState() => _BusDetailsSheetState();
}

class _BusDetailsSheetState extends ConsumerState<BusDetailsSheet> {
  static const _refreshInterval = Duration(seconds: 30);

  String? _selectedStopId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    if (route == null) return;
    _selectedStopId = closestStop(widget.bus, route)?.id;
    if (_selectedStopId == null) return;
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted || _selectedStopId == null) return;
      ref.invalidate(
        busEtaProvider((busId: widget.bus.id, stopId: _selectedStopId!)),
      );
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;
    final route = widget.route;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus,
                  color: theme.colorScheme.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bus.plateNumber, style: theme.textTheme.titleLarge),
                    if (route != null)
                      Text(route.name,
                          style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (route != null && route.stops.isNotEmpty)
            _EtaSection(
              bus: bus,
              route: route,
              selectedStopId: _selectedStopId,
              onStopChanged: (id) {
                if (id == null) return;
                setState(() => _selectedStopId = id);
              },
            )
          else
            Text('No route info available',
                style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          _detailRow(Icons.speed,
              '${bus.speed?.toStringAsFixed(1) ?? '—'} km/h'),
          _detailRow(Icons.access_time, _freshnessLabel(bus)),
        ],
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

  String _freshnessLabel(Bus bus) {
    if (bus.lastUpdated != null) {
      return 'Updated ${_timeAgo(bus.lastUpdated!)}';
    }
    // Bus is in the active stream (we got RTDB data) but the record has no
    // numeric timestamp — most likely a record written before timestamps were
    // tracked. We know we have a live signal, but not how stale.
    if (bus.status == BusStatus.active) return 'Live';
    return 'No recent update';
  }

  String _timeAgo(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inSeconds < 60) return '${delta.inSeconds}s ago';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    return '${delta.inHours}h ago';
  }
}

class _EtaSection extends ConsumerWidget {
  final Bus bus;
  final BusRoute route;
  final String? selectedStopId;
  final ValueChanged<String?> onStopChanged;

  const _EtaSection({
    required this.bus,
    required this.route,
    required this.selectedStopId,
    required this.onStopChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final orderedStops = [...route.stops]
      ..sort((a, b) => a.order.compareTo(b.order));

    final etaAsync = selectedStopId != null
        ? ref.watch(busEtaProvider((busId: bus.id, stopId: selectedStopId!)))
        : const AsyncValue<int?>.data(null);

    final watching = selectedStopId != null &&
        ref
            .watch(watchlistProvider)
            .contains(WatchEntry(busId: bus.id, stopId: selectedStopId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('ETA to:'),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedStopId,
                items: orderedStops
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: onStopChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: etaAsync.when(
                data: (eta) => Text(
                  eta != null ? '$eta min' : '—',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                loading: () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => Text(
                  '—',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
            if (selectedStopId != null)
              TextButton.icon(
                onPressed: () => ref
                    .read(watchlistProvider.notifier)
                    .toggle(WatchEntry(
                        busId: bus.id, stopId: selectedStopId!)),
                icon: Icon(
                  watching
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  size: 18,
                ),
                label: Text(watching ? 'Watching' : 'Notify me'),
              ),
          ],
        ),
      ],
    );
  }
}
