import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';

class PlanRouteScreen extends ConsumerStatefulWidget {
  const PlanRouteScreen({super.key});

  @override
  ConsumerState<PlanRouteScreen> createState() => _PlanRouteScreenState();
}

class _PlanRouteScreenState extends ConsumerState<PlanRouteScreen> {
  String? _startStopName;
  String? _endStopName;

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(allRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Your Route'),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading routes: $e')),
        data: (routes) => _buildContent(routes),
      ),
    );
  }

  Widget _buildContent(List<BusRoute> routes) {
    final stopNames = _uniqueStopNames(routes);
    final matches = (_startStopName != null && _endStopName != null)
        ? _findMatchingRoutes(routes, _startStopName!, _endStopName!)
        : const <_MatchedRoute>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _StopPicker(
                label: 'Start',
                icon: Icons.trip_origin,
                value: _startStopName,
                options: stopNames,
                onChanged: (v) => setState(() => _startStopName = v),
              ),
              const SizedBox(height: 12),
              _StopPicker(
                label: 'Destination',
                icon: Icons.location_on,
                value: _endStopName,
                options: stopNames.where((n) => n != _startStopName).toList(),
                onChanged: (v) => setState(() => _endStopName = v),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildResults(matches),
        ),
      ],
    );
  }

  Widget _buildResults(List<_MatchedRoute> matches) {
    if (_startStopName == null || _endStopName == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Select start and destination to see matching routes',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (matches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No direct routes between these stops',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final m = matches[i];
        return _RouteMatchCard(
          match: m,
          onTap: () => context.push(
            '/route-preview/${m.route.id}?start=${m.startStop.id}&end=${m.endStop.id}',
          ),
        );
      },
    );
  }

  static List<String> _uniqueStopNames(List<BusRoute> routes) {
    final names = <String>{};
    for (final r in routes) {
      for (final s in r.stops) {
        names.add(s.name);
      }
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  static List<_MatchedRoute> _findMatchingRoutes(
    List<BusRoute> routes,
    String startName,
    String endName,
  ) {
    final matches = <_MatchedRoute>[];
    for (final route in routes) {
      if (!route.isActive) continue;
      BusStop? start;
      BusStop? end;
      for (final s in route.stops) {
        if (s.name == startName && start == null) start = s;
        if (s.name == endName && end == null) end = s;
      }
      if (start != null && end != null && start.order < end.order) {
        matches.add(_MatchedRoute(route: route, startStop: start, endStop: end));
      }
    }
    return matches;
  }
}

class _MatchedRoute {
  final BusRoute route;
  final BusStop startStop;
  final BusStop endStop;

  const _MatchedRoute({
    required this.route,
    required this.startStop,
    required this.endStop,
  });

  int get stopCount => endStop.order - startStop.order + 1;
}

class _StopPicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _StopPicker({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      items: options
          .map((name) => DropdownMenuItem(value: name, child: Text(name)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _RouteMatchCard extends StatelessWidget {
  final _MatchedRoute match;
  final VoidCallback onTap;

  const _RouteMatchCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(match.route.color);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                        Text(
                          match.route.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          match.route.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.trip_origin, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(match.startStop.name)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(left: 7),
                child: SizedBox(
                  height: 14,
                  child: VerticalDivider(thickness: 2, width: 2),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(match.endStop.name)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${match.stopCount} stops',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
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
