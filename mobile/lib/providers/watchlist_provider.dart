import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifications.dart';
import '../models/models.dart';
import 'providers.dart';

const String _prefsKey = 'watchlist_v1';
const Duration _pollInterval = Duration(seconds: 30);
const int _etaThresholdMinutes = 2;

class WatchlistNotifier extends StateNotifier<List<WatchEntry>> {
  WatchlistNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    state = raw
        .map((s) =>
            WatchEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      state.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  bool isWatching(WatchEntry e) => state.contains(e);

  Future<void> toggle(WatchEntry e) async {
    if (state.contains(e)) {
      state = state.where((x) => x != e).toList();
    } else {
      state = [...state, e];
    }
    await _save();
  }

  Future<void> remove(WatchEntry e) async {
    if (!state.contains(e)) return;
    state = state.where((x) => x != e).toList();
    await _save();
  }
}

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, List<WatchEntry>>((ref) {
  return WatchlistNotifier();
});

/// Background poller: when the watchlist is non-empty, polls each entry's ETA
/// every 30s. When ETA drops to ≤ 2 min the entry fires a local notification
/// and is removed from the watchlist (one-shot — student re-arms by toggling
/// "Notify me" again).
class WatchMonitor {
  WatchMonitor(this._ref) {
    _ref.listen<List<WatchEntry>>(
      watchlistProvider,
      (_, next) => _onWatchlistChanged(next),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  Timer? _timer;

  void _onWatchlistChanged(List<WatchEntry> watchlist) {
    _timer?.cancel();
    if (watchlist.isEmpty) {
      _timer = null;
      return;
    }
    _timer = Timer.periodic(_pollInterval, (_) => _tick());
    // Kick off an immediate check so toggling on doesn't wait 30s for the
    // first reading.
    unawaited(_tick());
  }

  Future<void> _tick() async {
    final watchlist = _ref.read(watchlistProvider);
    if (watchlist.isEmpty) return;

    final repo = _ref.read(busRepositoryProvider);
    for (final entry in watchlist) {
      final eta = await repo.getEta(busId: entry.busId, stopId: entry.stopId);
      if (eta == null || eta > _etaThresholdMinutes) continue;
      // Auto-remove first so a race with the next tick can't re-fire.
      await _ref.read(watchlistProvider.notifier).remove(entry);
      await _notify(entry, eta);
    }
  }

  Future<void> _notify(WatchEntry entry, int etaMin) async {
    final buses = await _ref.read(allBusesProvider.future);
    final routes = await _ref.read(allRoutesProvider.future);
    final bus = buses.where((b) => b.id == entry.busId).firstOrNull;
    final route = routes.where((r) => r.id == bus?.routeId).firstOrNull;
    final stop =
        route?.stops.where((s) => s.id == entry.stopId).firstOrNull;

    await NotificationService.instance.showEtaAlert(
      title: '${bus?.plateNumber ?? 'Bus'} arriving in $etaMin min',
      body: 'At ${stop?.name ?? 'your stop'}',
    );
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Eagerly-initialized monitor — `ref.watch` from the student home screen so
/// it spins up on login and tears down on logout (when the student leaves
/// the home tree).
final watchMonitorProvider = Provider<WatchMonitor>((ref) {
  final monitor = WatchMonitor(ref);
  ref.onDispose(monitor.dispose);
  return monitor;
});
