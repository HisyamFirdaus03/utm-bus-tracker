import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';

class BusScheduleScreen extends ConsumerWidget {
  const BusScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(allRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Schedule'),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading routes: $e')),
        data: (routes) {
          final visible = routes.where((r) => r.isActive).toList();
          if (visible.isEmpty) {
            return const Center(child: Text('No active routes'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length,
            itemBuilder: (context, i) => _ScheduleCard(route: visible[i]),
          );
        },
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final BusRoute route;
  const _ScheduleCard({required this.route});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(route.color);
    final schedule = route.schedule;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        route.description,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (schedule != null) ...[
              _ScheduleRow(
                icon: Icons.schedule,
                label: 'Operating hours',
                value: '${schedule.departureTime} – ${schedule.arrivalTime}',
              ),
              _ScheduleRow(
                icon: Icons.repeat,
                label: 'Frequency',
                value: 'Every ${schedule.frequencyMinutes} min',
              ),
            ] else
              Text(
                'Schedule not available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            const SizedBox(height: 6),
            _ScheduleRow(
              icon: Icons.alt_route,
              label: 'Stops',
              value: '${route.stops.length}',
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return Colors.blueGrey;
    return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
  }
}

class _ScheduleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ScheduleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
