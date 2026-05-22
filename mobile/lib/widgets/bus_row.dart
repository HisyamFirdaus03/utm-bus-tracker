import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geo.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/watchlist_provider.dart';
import '../theme/app_theme.dart';
import '../theme/route_colors.dart';

/// Vertical bus row used in the expanded bottom sheet — same color
/// stripe + plate + ETA as the [BusCard], plus next-stops preview and
/// occupancy bar. See HANDOFF.md §3f.
class BusRow extends ConsumerWidget {
  final Bus bus;
  final BusRoute? route;
  final VoidCallback? onTap;

  const BusRow({
    super.key,
    required this.bus,
    required this.route,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeColor = colorForRoute(route);
    final stop = route != null ? closestStop(bus, route!) : null;
    final etaAsync = stop != null
        ? ref.watch(busEtaProvider((busId: bus.id, stopId: stop.id)))
        : const AsyncValue<int?>.data(null);

    final watched = stop != null &&
        ref
            .watch(watchlistProvider)
            .contains(WatchEntry(busId: bus.id, stopId: stop.id));

    final orderedStops = (route?.stops.toList() ?? [])
      ..sort((a, b) => a.order.compareTo(b.order));
    final nextStops = orderedStops.take(3).toList();

    final occupancy = (bus.id.hashCode % 100) / 100.0;
    final occColor = AppTheme.occupancyColor(occupancy);
    final occPct = (occupancy * 100).round();
    final statusLabel = bus.status == BusStatus.active ? 'On time' : bus.status.name;
    final etaValue = etaAsync.whenOrNull(data: (e) => e);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                offset: Offset(0, 4),
                color: Color(0x0F14080A),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 5, color: routeColor),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: routeColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.directions_bus,
                              size: 19, color: routeColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      (route?.name ?? '—').toUpperCase(),
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.label(
                                        size: 10,
                                        weight: FontWeight.w700,
                                        color: routeColor,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  if (watched) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '· WATCHED',
                                      style: AppTheme.label(
                                        size: 9,
                                        weight: FontWeight.w700,
                                        color: AppTheme.accent,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      bus.plateNumber,
                                      style: AppTheme.plate(size: 14),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: routeColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      etaValue != null ? '${etaValue}m' : '—',
                                      style: AppTheme.label(
                                        size: 11,
                                        weight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      stop != null ? 'to ${stop.name}' : '',
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.label(
                                        size: 11,
                                        weight: FontWeight.w500,
                                        color: AppTheme.ink500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (nextStops.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _NextStopsLine(stops: nextStops),
                    ],
                    const SizedBox(height: 10),
                    _OccupancyBar(
                      percent: occPct,
                      color: occColor,
                      statusLabel: statusLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextStopsLine extends StatelessWidget {
  final List<BusStop> stops;
  const _NextStopsLine({required this.stops});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const Icon(Icons.place_outlined, size: 11, color: AppTheme.ink400),
      const SizedBox(width: 6),
    ];
    for (var i = 0; i < stops.length; i++) {
      children.add(
        Flexible(
          child: Text(
            stops[i].name,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.label(
              size: 10.5,
              weight: i == 0 ? FontWeight.w600 : FontWeight.w500,
              color: i == 0 ? AppTheme.ink900 : AppTheme.ink500,
            ),
          ),
        ),
      );
      if (i < stops.length - 1) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('›',
              style: AppTheme.label(
                size: 11,
                weight: FontWeight.w500,
                color: AppTheme.ink300,
              )),
        ));
      }
    }
    return Row(children: children);
  }
}

class _OccupancyBar extends StatelessWidget {
  final int percent;
  final Color color;
  final String statusLabel;

  const _OccupancyBar({
    required this.percent,
    required this.color,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: AppTheme.ink900.withValues(alpha: 0.05)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percent / 100),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    builder: (context, value, _) {
                      return FractionallySizedBox(
                        widthFactor: value.clamp(0.0, 1.0),
                        child: Container(color: color),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$percent% · $statusLabel',
          style: AppTheme.label(
            size: 10.5,
            weight: FontWeight.w600,
            color: AppTheme.ink500,
          ),
        ),
      ],
    );
  }
}
