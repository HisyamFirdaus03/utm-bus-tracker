import 'package:flutter/material.dart';

import '../models/models.dart';

class RouteFilterChips extends StatelessWidget {
  final List<BusRoute> routes;
  final String? selectedRouteId;
  final ValueChanged<String?> onSelected;

  const RouteFilterChips({
    super.key,
    required this.routes,
    required this.selectedRouteId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: selectedRouteId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...routes.map(
            (route) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(route.name),
                selected: selectedRouteId == route.id,
                onSelected: (_) => onSelected(
                  selectedRouteId == route.id ? null : route.id,
                ),
                avatar: CircleAvatar(
                  backgroundColor: _hexToColor(route.color),
                  radius: 6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
