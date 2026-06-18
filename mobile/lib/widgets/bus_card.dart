import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geo.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/watchlist_provider.dart';
import '../theme/app_theme.dart';
import '../theme/route_colors.dart';

/// Horizontal-scroller card: 232dp wide, colored left stripe, plate +
/// route name, ETA chip, status footer with a pulsing dot.
/// See HANDOFF.md §3e.
class BusCard extends ConsumerStatefulWidget {
  final Bus bus;
  final AsyncValue<List<BusRoute>> routesAsync;
  final VoidCallback? onTap;

  const BusCard({
    super.key,
    required this.bus,
    required this.routesAsync,
    this.onTap,
  });

  @override
  ConsumerState<BusCard> createState() => _BusCardState();
}

class _BusCardState extends ConsumerState<BusCard>
    with TickerProviderStateMixin {
  late final AnimationController _dotPulse;
  late final AnimationController _pressAnim;

  @override
  void initState() {
    super.initState();
    _dotPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.985,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _dotPulse.dispose();
    _pressAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;
    final route = widget.routesAsync.whenOrNull(
      data: (routes) => routes.where((r) => r.id == bus.routeId).firstOrNull,
    );
    final routeColor = colorForRoute(route);

    final atStop = route != null ? arrivedStop(bus, route) : null;
    final nextStop = route != null ? pickNextStop(bus, route) : null;
    // Show ETA to the upcoming stop. When the bus is parked at a stop, we
    // surface "Arrived" instead and skip the ETA fetch entirely.
    final etaAsync = (atStop == null && nextStop != null)
        ? ref.watch(busEtaProvider((busId: bus.id, stopId: nextStop.id)))
        : const AsyncValue<int?>.data(null);

    final watched = nextStop != null &&
        ref
            .watch(watchlistProvider)
            .contains(WatchEntry(busId: bus.id, stopId: nextStop.id));

    final isActive = bus.status == BusStatus.active;

    return GestureDetector(
      onTapDown: (_) => _pressAnim.reverse(),
      onTapUp: (_) => _pressAnim.forward(),
      onTapCancel: () => _pressAnim.forward(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _pressAnim,
        child: Container(
          width: 232,
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
              Positioned.fill(
                left: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(width: 5, color: routeColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TopRow(
                      route: route,
                      routeColor: routeColor,
                      watched: watched,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bus.plateNumber,
                      style: AppTheme.plate(size: 15),
                    ),
                    const SizedBox(height: 12),
                    if (atStop != null)
                      _ArrivedChip(stopName: atStop.name)
                    else
                      _EtaChip(
                        routeColor: routeColor,
                        etaAsync: etaAsync,
                        destination: nextStop?.name,
                      ),
                    const SizedBox(height: 10),
                    _StatusFooter(
                      pulse: _dotPulse,
                      isActive: isActive,
                      lastUpdated: bus.lastUpdated,
                      statusName: bus.status.name,
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

class _TopRow extends StatelessWidget {
  final BusRoute? route;
  final Color routeColor;
  final bool watched;

  const _TopRow({
    required this.route,
    required this.routeColor,
    required this.watched,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
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
        ),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: routeColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.directions_bus, size: 15, color: routeColor),
        ),
      ],
    );
  }
}

class _EtaChip extends StatelessWidget {
  final Color routeColor;
  final AsyncValue<int?> etaAsync;
  final String? destination;

  const _EtaChip({
    required this.routeColor,
    required this.etaAsync,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    final etaValue = etaAsync.whenOrNull(data: (e) => e);
    final etaText = etaValue != null ? '${etaValue}m' : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: routeColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: routeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              etaText,
              style: AppTheme.label(
                size: 11,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              destination != null ? 'to $destination' : 'next stop',
              overflow: TextOverflow.ellipsis,
              style: AppTheme.label(
                size: 11,
                weight: FontWeight.w500,
                color: AppTheme.ink700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrivedChip extends StatelessWidget {
  final String stopName;
  const _ArrivedChip({required this.stopName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.routeA.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.routeA,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check, size: 11, color: Colors.white),
                const SizedBox(width: 3),
                Text(
                  'Arrived',
                  style: AppTheme.label(
                    size: 11,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'at $stopName',
              overflow: TextOverflow.ellipsis,
              style: AppTheme.label(
                size: 11,
                weight: FontWeight.w500,
                color: AppTheme.ink700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFooter extends StatelessWidget {
  final Animation<double> pulse;
  final bool isActive;
  final DateTime? lastUpdated;
  final String statusName;

  const _StatusFooter({
    required this.pulse,
    required this.isActive,
    required this.lastUpdated,
    required this.statusName,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.routeA : AppTheme.ink400;
    final label = _label();
    return Row(
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.45).animate(pulse),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.label(
              size: 10.5,
              weight: FontWeight.w600,
              color: AppTheme.ink500,
            ),
          ),
        ),
      ],
    );
  }

  String _label() {
    if (!isActive) return statusName;
    if (lastUpdated == null) return 'Live';
    final delta = DateTime.now().difference(lastUpdated!);
    if (delta.inSeconds < 60) return 'Live · ${delta.inSeconds}s ago';
    if (delta.inMinutes < 60) return 'Live · ${delta.inMinutes}m ago';
    return 'Live · ${delta.inHours}h ago';
  }
}
