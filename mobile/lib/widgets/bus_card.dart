import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class BusCard extends ConsumerWidget {
  final Bus bus;
  final AsyncValue<List<BusRoute>> routesAsync;

  const BusCard({
    super.key,
    required this.bus,
    required this.routesAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeName = routesAsync.whenOrNull(
      data: (routes) {
        try {
          return routes.firstWhere((r) => r.id == bus.routeId).name;
        } catch (_) {
          return null;
        }
      },
    );
    final etaAsync = ref.watch(busEtaProvider(bus.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Bus icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bus.status == BusStatus.active
                    ? Colors.green.withAlpha(30)
                    : Colors.grey.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.directions_bus,
                color:
                    bus.status == BusStatus.active ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),

            // Bus info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bus.plateNumber,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    routeName ?? bus.routeId,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),

            // ETA / status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                etaAsync.when(
                  data: (eta) => eta != null
                      ? Text(
                          '$eta min',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: bus.status == BusStatus.active
                        ? Colors.green.withAlpha(30)
                        : Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bus.status == BusStatus.active ? 'ETA' : bus.status.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: bus.status == BusStatus.active
                          ? Colors.green[700]
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
