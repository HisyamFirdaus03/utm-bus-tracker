import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/route_filter_chips.dart';

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final busesAsync = ref.watch(allBusesProvider);
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
          // Greeting
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Hello, ${user?.name ?? 'Student'}!',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          // Route filter chips
          routesAsync.when(
            data: (routes) => RouteFilterChips(
              routes: routes,
              selectedRouteId: selectedRoute,
              onSelected: (routeId) {
                ref.read(selectedRouteProvider.notifier).state = routeId;
              },
            ),
            loading: () =>
                const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading routes: $e'),
            ),
          ),

          // Map placeholder
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Google Maps will appear here',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Requires Google Maps API key',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Active buses list
          Expanded(
            flex: 2,
            child: busesAsync.when(
              data: (buses) {
                final filtered = selectedRoute != null
                    ? buses.where((b) => b.routeId == selectedRoute).toList()
                    : buses;
                final activeBuses =
                    filtered.where((b) => b.status == BusStatus.active).toList();

                if (activeBuses.isEmpty) {
                  return const Center(child: Text('No active buses on this route'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: activeBuses.length,
                  itemBuilder: (context, index) {
                    return BusCard(
                      bus: activeBuses[index],
                      routesAsync: routesAsync,
                    );
                  },
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
}
