import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geo.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/watchlist_provider.dart';
import '../theme/app_theme.dart';
import '../theme/route_colors.dart';

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
    // Prefer the stop the bus is currently *at* (if any) so the headline
    // reads "Arrived" the moment the sheet opens; otherwise fall back to
    // the upcoming stop (driver-declared or GPS-inferred).
    _selectedStopId = arrivedStop(widget.bus, route)?.id ??
        pickNextStop(widget.bus, route)?.id;
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            offset: Offset(0, -8),
            color: Color(0x1414080A),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.ink300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Header(bus: bus, route: route),
            const SizedBox(height: 20),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'No route info available',
                  style: AppTheme.label(size: 13, color: AppTheme.ink500),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Header — bus identity + live status
// ─────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final Bus bus;
  final BusRoute? route;

  const _Header({required this.bus, required this.route});

  @override
  Widget build(BuildContext context) {
    final routeColor = colorForRoute(route);
    final isActive = bus.status == BusStatus.active;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: routeColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_bus, color: routeColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LiveBadge(isActive: isActive),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  bus.plateNumber,
                  style: AppTheme.plate(size: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  _statsLine(bus),
                  style: AppTheme.label(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppTheme.ink500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statsLine(Bus bus) {
    final speed = bus.speed != null ? '${bus.speed!.toStringAsFixed(0)} km/h' : null;
    final ago = _freshness(bus);
    return [?speed, ago].join(' · ');
  }

  String _freshness(Bus bus) {
    if (bus.lastUpdated != null) return 'updated ${_timeAgo(bus.lastUpdated!)}';
    if (bus.status == BusStatus.active) return 'live';
    return 'offline';
  }

  String _timeAgo(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inSeconds < 60) return '${delta.inSeconds}s ago';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    return '${delta.inHours}h ago';
  }
}

class _LiveBadge extends StatelessWidget {
  final bool isActive;
  const _LiveBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.routeA : AppTheme.ink400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'LIVE' : 'OFFLINE',
            style: AppTheme.label(
              size: 9,
              weight: FontWeight.w800,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ETA section — stop picker + big ETA / Arrived card + Notify CTA
// ─────────────────────────────────────────────────────────────────────
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
    final routeColor = colorForRoute(route);
    final orderedStops = [...route.stops]
      ..sort((a, b) => a.order.compareTo(b.order));

    final selectedStop = selectedStopId == null
        ? null
        : orderedStops.where((s) => s.id == selectedStopId).firstOrNull;
    final arrivedHere =
        selectedStop != null && isArrivedAtStop(bus, selectedStop);

    final etaAsync = (arrivedHere || selectedStopId == null)
        ? const AsyncValue<int?>.data(null)
        : ref.watch(busEtaProvider((busId: bus.id, stopId: selectedStopId!)));

    final watching = selectedStopId != null &&
        ref
            .watch(watchlistProvider)
            .contains(WatchEntry(busId: bus.id, stopId: selectedStopId!));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            arrivedHere ? 'CURRENT STOP' : 'NEXT STOP',
            style: AppTheme.label(
              size: 10,
              weight: FontWeight.w700,
              color: AppTheme.ink500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _StopPicker(
            orderedStops: orderedStops,
            selectedStopId: selectedStopId,
            onChanged: onStopChanged,
          ),
          const SizedBox(height: 14),
          if (arrivedHere)
            _ArrivedDisplay(stopName: selectedStop.name)
          else
            _EtaDisplay(
              routeColor: routeColor,
              etaAsync: etaAsync,
              destination: selectedStop?.name,
            ),
          if (selectedStopId != null && !arrivedHere) ...[
            const SizedBox(height: 16),
            _NotifyButton(
              watching: watching,
              onPressed: () => ref
                  .read(watchlistProvider.notifier)
                  .toggle(WatchEntry(busId: bus.id, stopId: selectedStopId!)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StopPicker extends StatelessWidget {
  final List<BusStop> orderedStops;
  final String? selectedStopId;
  final ValueChanged<String?> onChanged;

  const _StopPicker({
    required this.orderedStops,
    required this.selectedStopId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F14080A)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedStopId,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.ink500),
          style: AppTheme.label(
            size: 14,
            weight: FontWeight.w600,
            color: AppTheme.ink900,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          selectedItemBuilder: (context) => orderedStops
              .map(
                (s) => Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: AppTheme.ink500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.label(
                          size: 14,
                          weight: FontWeight.w600,
                          color: AppTheme.ink900,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
          items: orderedStops
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ArrivedDisplay extends StatelessWidget {
  final String stopName;
  const _ArrivedDisplay({required this.stopName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.routeA.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.routeA.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppTheme.routeA,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Arrived',
                  style: AppTheme.label(
                    size: 22,
                    weight: FontWeight.w800,
                    color: AppTheme.routeA,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'at $stopName',
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.label(
                    size: 12,
                    weight: FontWeight.w500,
                    color: AppTheme.ink700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EtaDisplay extends StatelessWidget {
  final Color routeColor;
  final AsyncValue<int?> etaAsync;
  final String? destination;

  const _EtaDisplay({
    required this.routeColor,
    required this.etaAsync,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: routeColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: routeColor.withValues(alpha: 0.18)),
      ),
      child: etaAsync.when(
        data: (eta) => Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: routeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                eta != null ? '$eta' : '—',
                style: AppTheme.label(
                  size: 22,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    eta == null
                        ? 'ETA unavailable'
                        : eta == 1
                            ? 'minute away'
                            : 'minutes away',
                    style: AppTheme.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppTheme.ink900,
                    ),
                  ),
                  if (destination != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'to $destination',
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.label(
                        size: 11,
                        weight: FontWeight.w500,
                        color: AppTheme.ink500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 44,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.ink400, size: 20),
            const SizedBox(width: 8),
            Text(
              'Could not load ETA',
              style: AppTheme.label(size: 13, color: AppTheme.ink500),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifyButton extends StatelessWidget {
  final bool watching;
  final VoidCallback onPressed;

  const _NotifyButton({required this.watching, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (watching) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.notifications_active, size: 18),
          label: const Text('Watching — tap to stop'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.crimson,
            side: const BorderSide(color: AppTheme.crimson, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: AppTheme.label(
              size: 14,
              weight: FontWeight.w600,
              color: AppTheme.crimson,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.notifications_outlined, size: 18),
        label: const Text('Notify me when close'),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.crimson,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: AppTheme.label(
            size: 14,
            weight: FontWeight.w600,
            color: Colors.white,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
