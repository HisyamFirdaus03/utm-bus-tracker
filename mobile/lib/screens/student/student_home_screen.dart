import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants.dart';
import '../../core/geo.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../providers/watchlist_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/route_colors.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/bus_details_sheet.dart';
import '../../widgets/bus_row.dart';
import '../../widgets/route_filter_chips.dart';

enum BusSort { nearest, soonest, watched }

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  late final AnimationController _livePulse;
  BusSort _sort = BusSort.nearest;

  // Sheet snap targets
  static const _peekSize = 0.28;
  static const _expandedSize = 0.78;

  @override
  void initState() {
    super.initState();
    _livePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _livePulse.dispose();
    _sheetController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  bool get _isExpanded {
    if (!_sheetController.isAttached) return false;
    return _sheetController.size > (_peekSize + _expandedSize) / 2;
  }

  void _toggleSheet() {
    if (!_sheetController.isAttached) return;
    final target = _isExpanded ? _peekSize : _expandedSize;
    _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeBusesAsync = ref.watch(activeBusesStreamProvider);
    final routesAsync = ref.watch(allRoutesProvider);
    final selectedRouteId = ref.watch(selectedRouteProvider);
    final watchlist = ref.watch(watchlistProvider);
    final watchlistCount = watchlist.length;
    // Eagerly construct the watch monitor — spins up the polling timer.
    ref.watch(watchMonitorProvider);

    final routes = routesAsync.valueOrNull ?? const <BusRoute>[];
    final allBuses = activeBusesAsync.valueOrNull ?? const <Bus>[];
    final routeFiltered = selectedRouteId == null
        ? allBuses
        : allBuses.where((b) => b.routeId == selectedRouteId).toList();
    final filteredBuses = _applySort(routeFiltered, routes, watchlist);

    return Scaffold(
      backgroundColor: AppTheme.paper,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Full-bleed map ──────────────────────────────────────
          Positioned.fill(child: _buildMap(routes, filteredBuses, selectedRouteId)),

          // ── Floating map controls ───────────────────────────────
          AnimatedBuilder(
            animation: _sheetController.isAttached
                ? _sheetController
                : const AlwaysStoppedAnimation(0),
            builder: (context, _) {
              final size = _sheetController.isAttached
                  ? _sheetController.size
                  : _peekSize;
              final screenHeight = MediaQuery.of(context).size.height;
              final bottom = size * screenHeight + 16;
              return Positioned(
                right: 12,
                bottom: bottom,
                child: _MapControls(
                  onLocate: () => _recenterToUtm(),
                ),
              );
            },
          ),

          // ── Floating app bar (blur) ─────────────────────────────
          _FloatingAppBar(
            watchlistCount: watchlistCount,
            onSchedule: () => context.push('/schedule'),
            onWatchlist: () => context.push('/watchlist'),
            onMenuSelected: _handleMenu,
          ),

          // ── Floating route chips ────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 0,
            right: 0,
            child: routesAsync.when(
              data: (routes) => RouteFilterChips(
                routes: routes,
                selectedRouteId: selectedRouteId,
                onSelected: (id) =>
                    ref.read(selectedRouteProvider.notifier).state = id,
              ),
              loading: () => const SizedBox(height: 52),
              error: (_, _) => const SizedBox(height: 52),
            ),
          ),

          // ── Bottom sheet ────────────────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _peekSize,
            minChildSize: _peekSize,
            maxChildSize: _expandedSize,
            snap: true,
            snapSizes: const [_peekSize, _expandedSize],
            builder: (context, scrollController) {
              return _Sheet(
                scrollController: scrollController,
                livePulse: _livePulse,
                buses: filteredBuses,
                routes: routes,
                routesAsync: routesAsync,
                sort: _sort,
                onSortChanged: (s) => setState(() => _sort = s),
                onToggle: _toggleSheet,
                onBusTap: _expandAndScrollTo,
                onStopTap: (_) {},
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Sort / filter ────────────────────────────────────────────────

  List<Bus> _applySort(
    List<Bus> buses,
    List<BusRoute> routes,
    List<WatchEntry> watchlist,
  ) {
    if (_sort == BusSort.watched) {
      return buses.where((b) => watchlist.any((w) => w.busId == b.id)).toList();
    }
    final sorted = [...buses];
    sorted.sort((a, b) => _sortKey(a, routes).compareTo(_sortKey(b, routes)));
    return sorted;
  }

  double _sortKey(Bus bus, List<BusRoute> routes) {
    if (bus.latitude == null || bus.longitude == null) return double.infinity;
    final route = routes.where((r) => r.id == bus.routeId).firstOrNull;
    if (route == null) return double.infinity;
    final stop = pickNextStop(bus, route);
    if (stop == null) return double.infinity;
    final distance = haversineMeters(
      bus.latitude!,
      bus.longitude!,
      stop.latitude,
      stop.longitude,
    );
    if (_sort == BusSort.nearest) return distance;
    // Soonest: distance / speed (floor speed at walking pace so a stalled
    // bus doesn't sort to infinity).
    final speedKmh = ((bus.speed ?? 0).clamp(5, 60)).toDouble();
    final speedMs = speedKmh * 1000 / 3600;
    return distance / speedMs; // seconds
  }

  // ── Map ──────────────────────────────────────────────────────────

  Widget _buildMap(List<BusRoute> routes, List<Bus> buses, String? selectedId) {
    return GoogleMap(
      style: _mapStyle,
      initialCameraPosition: const CameraPosition(
        target: AppConstants.utmCampusCenter,
        zoom: AppConstants.defaultMapZoom,
      ),
      onMapCreated: (c) => _mapController = c,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      // Polylines intentionally omitted: stop lat/lngs in the seed aren't
      // road-aligned, so connecting them with straight lines reads as
      // "lines through buildings". Route Preview still draws a polyline
      // for the dedicated single-segment view where it makes sense.
      markers: _buildMarkers(buses, routes, selectedId),
      padding: const EdgeInsets.only(bottom: 200),
    );
  }

  Set<Marker> _buildMarkers(
    List<Bus> buses,
    List<BusRoute> routes,
    String? selectedId,
  ) {
    final visible = selectedId != null
        ? buses.where((b) => b.routeId == selectedId)
        : buses;

    return visible
        .where((b) => b.latitude != null && b.longitude != null)
        .map((bus) {
      final route = routes.where((r) => r.id == bus.routeId).firstOrNull;
      return Marker(
        markerId: MarkerId(bus.id),
        position: LatLng(bus.latitude!, bus.longitude!),
        infoWindow: InfoWindow(
          title: bus.plateNumber,
          snippet: route?.name ?? bus.routeId,
        ),
        onTap: () => _showBusDetails(bus, route),
      );
    }).toSet();
  }

  void _recenterToUtm() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        AppConstants.utmCampusCenter,
        AppConstants.defaultMapZoom,
      ),
    );
  }

  void _expandAndScrollTo(Bus bus) {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      _expandedSize,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _showBusDetails(Bus bus, BusRoute? route) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BusDetailsSheet(bus: bus, route: route),
    );
  }

  void _handleMenu(String value) {
    switch (value) {
      case 'plan-route':
        context.push('/plan-route');
      case 'feedback':
        context.push('/feedback');
      case 'logout':
        ref.read(authStateProvider.notifier).logout();
    }
  }
}

// Light, warm, low-detail Google Maps JSON.
const String _mapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#EDE7DE"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6B5F5D"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#FAF7F4"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#E5DED5"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#B4D6EE"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#CFE0BD"}]},
  {"featureType":"administrative","elementType":"labels","stylers":[{"visibility":"on"}]}
]
''';

// ─────────────────────────────────────────────────────────────────────
// App bar (floating, blurred)
// ─────────────────────────────────────────────────────────────────────
class _FloatingAppBar extends StatelessWidget {
  final int watchlistCount;
  final VoidCallback onSchedule;
  final VoidCallback onWatchlist;
  final ValueChanged<String> onMenuSelected;

  const _FloatingAppBar({
    required this.watchlistCount,
    required this.onSchedule,
    required this.onWatchlist,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: Colors.white.withValues(alpha: 0.88),
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const _UtmBadge(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BusTracker',
                          style: AppTheme.label(
                            size: 15,
                            weight: FontWeight.w700,
                            color: AppTheme.ink900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'UTM Skudai · Live',
                          style: AppTheme.label(
                            size: 11,
                            weight: FontWeight.w500,
                            color: AppTheme.ink500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AppBarIconButton(
                    icon: Icons.schedule_outlined,
                    tooltip: 'Schedule',
                    onTap: onSchedule,
                  ),
                  _AppBarIconButton(
                    icon: Icons.notifications_outlined,
                    tooltip: 'Watchlist',
                    onTap: onWatchlist,
                    badgeCount: watchlistCount,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.menu, color: AppTheme.ink700),
                    color: Colors.white,
                    onSelected: onMenuSelected,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'plan-route',
                        child: ListTile(
                          leading: Icon(Icons.alt_route),
                          title: Text('Plan Route'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'feedback',
                        child: ListTile(
                          leading: Icon(Icons.feedback_outlined),
                          title: Text('Feedback'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: ListTile(
                          leading: Icon(Icons.logout),
                          title: Text('Logout'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UtmBadge extends StatelessWidget {
  const _UtmBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.crimson, AppTheme.crimsonDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            blurRadius: 2,
            offset: Offset(0, 1),
            color: Color(0x4D5E1220),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'UTM',
        style: AppTheme.label(
          size: 11,
          weight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  const _AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(icon, size: 20, color: AppTheme.ink700),
                ),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$badgeCount',
                    style: AppTheme.label(
                      size: 9,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Map controls (locate, layers)
// ─────────────────────────────────────────────────────────────────────
class _MapControls extends StatelessWidget {
  final VoidCallback onLocate;
  const _MapControls({required this.onLocate});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MapButton(
          icon: Icons.layers_outlined,
          tooltip: 'Layers',
          color: AppTheme.ink700,
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _MapButton(
          icon: Icons.my_location,
          tooltip: 'My location',
          color: AppTheme.crimson,
          onTap: onLocate,
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  offset: Offset(0, 4),
                  color: Color(0x1414080A),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Bottom sheet
// ─────────────────────────────────────────────────────────────────────
class _Sheet extends ConsumerWidget {
  final ScrollController scrollController;
  final Animation<double> livePulse;
  final List<Bus> buses;
  final List<BusRoute> routes;
  final AsyncValue<List<BusRoute>> routesAsync;
  final BusSort sort;
  final ValueChanged<BusSort> onSortChanged;
  final VoidCallback onToggle;
  final ValueChanged<Bus> onBusTap;
  final ValueChanged<BusStop> onStopTap;

  const _Sheet({
    required this.scrollController,
    required this.livePulse,
    required this.buses,
    required this.routes,
    required this.routesAsync,
    required this.sort,
    required this.onSortChanged,
    required this.onToggle,
    required this.onBusTap,
    required this.onStopTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleRoutes = routes;
    final stops = _nearbyStops(visibleRoutes);

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
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _DragHandle(onTap: onToggle),
                _SheetHeader(
                  count: buses.length,
                  livePulse: livePulse,
                  onToggle: onToggle,
                ),
                _HorizontalCardScroller(
                  buses: buses,
                  routesAsync: routesAsync,
                  onBusTap: onBusTap,
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SortPills(current: sort, onChanged: onSortChanged),
                const SizedBox(height: 12),
                for (final bus in buses) ...[
                  BusRow(
                    bus: bus,
                    route: routes
                        .where((r) => r.id == bus.routeId)
                        .firstOrNull,
                  ),
                  const SizedBox(height: 10),
                ],
                if (buses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        sort == BusSort.watched
                            ? 'No watched buses live right now'
                            : 'No active buses',
                        style: AppTheme.label(
                          size: 13,
                          color: AppTheme.ink500,
                        ),
                      ),
                    ),
                  ),
                if (stops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SectionHeader(
                    label: 'Nearby stops',
                    actionLabel: 'View all',
                    onAction: () {},
                  ),
                  const SizedBox(height: 8),
                  for (final stop in stops)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _NearbyStopRow(
                        stop: stop,
                        routes: visibleRoutes.where(
                          (r) => r.stops.any((s) => s.id == stop.id),
                        ).toList(),
                        onTap: () => onStopTap(stop),
                      ),
                    ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<BusStop> _nearbyStops(List<BusRoute> routes) {
    // No user location wired yet — pick the first three unique stops
    // across visible routes (ordered by their `order` field).
    final seen = <String>{};
    final out = <BusStop>[];
    final allStops = <BusStop>[
      for (final r in routes) ...[...r.stops]..sort((a, b) => a.order.compareTo(b.order))
    ];
    for (final s in allStops) {
      if (seen.add(s.id)) {
        out.add(s);
        if (out.length >= 3) break;
      }
    }
    return out;
  }
}

class _DragHandle extends StatelessWidget {
  final VoidCallback onTap;
  const _DragHandle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.ink300,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final int count;
  final Animation<double> livePulse;
  final VoidCallback onToggle;

  const _SheetHeader({
    required this.count,
    required this.livePulse,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      child: Row(
        children: [
          _LivePulseDot(animation: livePulse),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$count ${count == 1 ? 'bus' : 'buses'}',
                  style: AppTheme.label(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppTheme.ink900,
                  ),
                ),
                TextSpan(
                  text: ' live now',
                  style: AppTheme.label(
                    size: 15,
                    weight: FontWeight.w600,
                    color: AppTheme.ink500,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onToggle,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.ink500,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            label: const Icon(Icons.keyboard_arrow_up, size: 16),
            icon: Text(
              'See all',
              style: AppTheme.label(
                size: 11.5,
                weight: FontWeight.w600,
                color: AppTheme.ink500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePulseDot extends StatelessWidget {
  final Animation<double> animation;
  const _LivePulseDot({required this.animation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: animation,
            builder: (_, _) {
              final t = animation.value;
              final scale = 0.6 + (2.2 - 0.6) * t;
              final opacity = (1 - t) * 0.6;
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppTheme.routeA,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.routeA,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalCardScroller extends StatelessWidget {
  final List<Bus> buses;
  final AsyncValue<List<BusRoute>> routesAsync;
  final ValueChanged<Bus> onBusTap;

  const _HorizontalCardScroller({
    required this.buses,
    required this.routesAsync,
    required this.onBusTap,
  });

  @override
  Widget build(BuildContext context) {
    if (buses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Text(
          'No active buses on this route',
          style: AppTheme.label(size: 12.5, color: AppTheme.ink500),
        ),
      );
    }
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        physics: const BouncingScrollPhysics(),
        itemCount: buses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => BusCard(
          bus: buses[i],
          routesAsync: routesAsync,
          onTap: () => onBusTap(buses[i]),
        ),
      ),
    );
  }
}

class _SortPills extends StatelessWidget {
  final BusSort current;
  final ValueChanged<BusSort> onChanged;

  const _SortPills({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Pill(
          label: 'Nearest',
          selected: current == BusSort.nearest,
          onTap: () => onChanged(BusSort.nearest),
        ),
        const SizedBox(width: 6),
        _Pill(
          label: 'Soonest',
          selected: current == BusSort.soonest,
          onTap: () => onChanged(BusSort.soonest),
        ),
        const SizedBox(width: 6),
        _Pill(
          label: 'Watched',
          selected: current == BusSort.watched,
          onTap: () => onChanged(BusSort.watched),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.ink900
                : AppTheme.ink900.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AppTheme.label(
              size: 11,
              weight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.ink700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.label,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTheme.label(
              size: 11,
              weight: FontWeight.w700,
              color: AppTheme.ink500,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: AppTheme.label(
                size: 11,
                weight: FontWeight.w600,
                color: AppTheme.crimson,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyStopRow extends StatelessWidget {
  final BusStop stop;
  final List<BusRoute> routes;
  final VoidCallback onTap;

  const _NearbyStopRow({
    required this.stop,
    required this.routes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.paper.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.place,
                  size: 14,
                  color: AppTheme.crimson,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.label(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppTheme.ink900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stop ${stop.order} · serves ${routes.length} route${routes.length == 1 ? '' : 's'}',
                      style: AppTheme.label(
                        size: 11,
                        weight: FontWeight.w500,
                        color: AppTheme.ink500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in routes) ...[
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorForRoute(r),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        letterForRoute(r),
                        style: AppTheme.label(
                          size: 9,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
