/// A (bus, stop) pair the student has asked to be notified about.
class WatchEntry {
  final String busId;
  final String stopId;

  const WatchEntry({required this.busId, required this.stopId});

  Map<String, dynamic> toJson() => {'busId': busId, 'stopId': stopId};

  factory WatchEntry.fromJson(Map<String, dynamic> json) => WatchEntry(
        busId: json['busId'] as String,
        stopId: json['stopId'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is WatchEntry && other.busId == busId && other.stopId == stopId;

  @override
  int get hashCode => Object.hash(busId, stopId);
}
