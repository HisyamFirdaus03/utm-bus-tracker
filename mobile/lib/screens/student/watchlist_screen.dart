import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../providers/watchlist_provider.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);
    final busesAsync = ref.watch(allBusesProvider);
    final routesAsync = ref.watch(allRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: watchlist.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: watchlist.length,
              itemBuilder: (context, i) {
                final entry = watchlist[i];
                final bus = busesAsync.valueOrNull
                    ?.where((b) => b.id == entry.busId)
                    .firstOrNull;
                final route = routesAsync.valueOrNull
                    ?.where((r) => r.id == bus?.routeId)
                    .firstOrNull;
                final stop = route?.stops
                    .where((s) => s.id == entry.stopId)
                    .firstOrNull;
                return _WatchlistTile(
                  entry: entry,
                  busPlate: bus?.plateNumber,
                  stopName: stop?.name,
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none,
              size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            "You're not watching any buses yet.",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a bus on the map, pick a stop, then "Notify me" to get an alert when it\'s within 2 minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _WatchlistTile extends ConsumerWidget {
  final WatchEntry entry;
  final String? busPlate;
  final String? stopName;

  const _WatchlistTile({
    required this.entry,
    this.busPlate,
    this.stopName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final etaAsync =
        ref.watch(busEtaProvider((busId: entry.busId, stopId: entry.stopId)));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.directions_bus, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(busPlate ?? entry.busId,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    'Notify at: ${stopName ?? entry.stopId}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
            ),
            etaAsync.when(
              data: (eta) => Text(
                eta != null ? '$eta min' : '—',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              loading: () => const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => const Text('—'),
            ),
            IconButton(
              tooltip: 'Stop watching',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  ref.read(watchlistProvider.notifier).remove(entry),
            ),
          ],
        ),
      ),
    );
  }
}
