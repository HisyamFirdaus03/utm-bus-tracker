import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/route_colors.dart';

/// Horizontal scroll of pill chips for filtering buses by route.
/// See HANDOFF.md §3b.
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
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _AllChip(
            selected: selectedRouteId == null,
            routes: routes,
            onTap: () => onSelected(null),
          ),
          for (final route in routes) ...[
            const SizedBox(width: 8),
            _RouteChip(
              route: route,
              selected: selectedRouteId == route.id,
              onTap: () => onSelected(
                selectedRouteId == route.id ? null : route.id,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AllChip extends StatelessWidget {
  final bool selected;
  final List<BusRoute> routes;
  final VoidCallback onTap;

  const _AllChip({
    required this.selected,
    required this.routes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      onTap: onTap,
      background: selected ? AppTheme.ink900 : Colors.white.withValues(alpha: 0.95),
      borderColor: selected
          ? AppTheme.ink900
          : const Color(0x0F14080A), // ink900 @ 6%
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            for (final route in routes.take(3)) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colorForRoute(route),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 2),
            ],
            const SizedBox(width: 4),
          ],
          Text(
            'All routes',
            style: AppTheme.label(
              size: 12.5,
              weight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.ink700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  final BusRoute route;
  final bool selected;
  final VoidCallback onTap;

  const _RouteChip({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorForRoute(route);
    return _ChipShell(
      onTap: onTap,
      background: selected
          ? color.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.95),
      borderColor: selected
          ? color.withValues(alpha: 0.33)
          : const Color(0x0F14080A),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            route.name,
            style: AppTheme.label(
              size: 12.5,
              weight: FontWeight.w600,
              color: selected ? color : AppTheme.ink700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipShell extends StatelessWidget {
  final VoidCallback onTap;
  final Color background;
  final Color borderColor;
  final Widget child;

  const _ChipShell({
    required this.onTap,
    required this.background,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                blurRadius: 8,
                offset: Offset(0, 2),
                color: Color(0x0D14080A),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
