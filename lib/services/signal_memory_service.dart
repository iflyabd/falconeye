import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ble_service.dart';
import 'wifi_csi_service.dart';
import 'cell_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V48.1 — SIGNAL MEMORY SERVICE
//  Stores sightings of BLE/WiFi/Cell signals in SharedPreferences.
//  Builds threat profiles: devices seen repeatedly get flagged.
//  Zero mock: only stores data from real hardware observations.
// ═══════════════════════════════════════════════════════════════════════════════

enum ThreatLevel { unknown, clean, suspicious, threat }

class SignalMemoryEntry {
  final String id;         // BLE MAC / WiFi BSSID / Cell tower ID
  final String type;       // 'BLE' | 'WiFi' | 'Cell'
  final String label;      // Device name / SSID / Tower ID
  final int firstRssi;
  final int peakRssi;
  final DateTime firstSeen;
  DateTime lastSeen;
  int seenCount;
  ThreatLevel threatLevel;
  String note;
  List<DateTime> sightingTimes;  // last 50 sighting timestamps

  SignalMemoryEntry({
    required this.id,
    required this.type,
    required this.label,
    required this.firstRssi,
    required this.peakRssi,
    required this.firstSeen,
    required this.lastSeen,
    required this.seenCount,
    this.threatLevel = ThreatLevel.unknown,
    this.note = '',
    List<DateTime>? sightingTimes,
  }) : sightingTimes = sightingTimes ?? [];

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'label': label,
    'firstRssi': firstRssi, 'peakRssi': peakRssi,
    'firstSeen': firstSeen.toIso8601String(),
    'lastSeen': lastSeen.toIso8601String(),
    'seenCount': seenCount,
    'threatLevel': threatLevel.index,
    'note': note,
    'sightingTimes': sightingTimes.map((t) => t.toIso8601String()).toList(),
  };

  factory SignalMemoryEntry.fromJson(Map<String, dynamic> j) => SignalMemoryEntry(
    id: j['id'], type: j['type'], label: j['label'],
    firstRssi: j['firstRssi'], peakRssi: j['peakRssi'],
    firstSeen: DateTime.parse(j['firstSeen']),
    lastSeen: DateTime.parse(j['lastSeen']),
    seenCount: j['seenCount'],
    threatLevel: ThreatLevel.values[j['threatLevel'] ?? 0],
    note: j['note'] ?? '',
    sightingTimes: (j['sightingTimes'] as List<dynamic>? ?? [])
        .map((t) => DateTime.parse(t as String)).toList(),
  );

  String get threatLabel => threatLevel.name.toUpperCase();
}

class SignalMemoryState {
  final Map<String, SignalMemoryEntry> entries;
  final bool isTracking;
  final int totalSightings;
  final DateTime? lastUpdate;

  const SignalMemoryState({
    this.entries = const {},
    this.isTracking = false,
    this.totalSightings = 0,
    this.lastUpdate,
  });

  SignalMemoryState copyWith({
    Map<String, SignalMemoryEntry>? entries,
    bool? isTracking,
    int? totalSightings,
    DateTime? lastUpdate,
  }) => SignalMemoryState(
    entries: entries ?? this.entries,
    isTracking: isTracking ?? this.isTracking,
    totalSightings: totalSightings ?? this.totalSightings,
    lastUpdate: lastUpdate ?? this.lastUpdate,
  );

  List<SignalMemoryEntry> get threats =>
      entries.values.where((e) => e.threatLevel == ThreatLevel.threat).toList()
        ..sort((a, b) => b.seenCount.compareTo(a.seenCount));

  List<SignalMemoryEntry> get suspicious =>
      entries.values.where((e) => e.threatLevel == ThreatLevel.suspicious).toList()
        ..sort((a, b) => b.seenCount.compareTo(a.seenCount));

  List<SignalMemoryEntry> get allSorted =>
      entries.values.toList()
        ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
}

class SignalMemoryService extends Notifier<SignalMemoryState> {
  static const _kPrefsKey = 'falcon_signal_memory_v481';
  StreamSubscription<BleScanState>? _bleSub;
  StreamSubscription<WiFiCSIState>? _wifiSub;
  StreamSubscription<List<CellularCell>>? _cellSub;
  Timer? _saveTimer;

  @override
  SignalMemoryState build() {
    ref.onDispose(_dispose);
    _load();
    return const SignalMemoryState();
  }

  void _dispose() {
    _bleSub?.cancel();
    _wifiSub?.cancel();
    _cellSub?.cancel();
    _saveTimer?.cancel();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entries = map.map((k, v) =>
          MapEntry(k, SignalMemoryEntry.fromJson(v as Map<String, dynamic>)));
      state = state.copyWith(entries: entries, totalSightings: entries.length);
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = state.entries.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_kPrefsKey, jsonEncode(map));
    } catch (_) {}
  }

  void startTracking() {
    if (state.isTracking) return;
    state = state.copyWith(isTracking: true);

    // BLE
    final bleNotifier = ref.read(bleServiceProvider.notifier);
    bleNotifier.startScan();
    // Listen via stream
    _bleSub = Stream.periodic(const Duration(seconds: 5)).asyncMap((_) async {
      return ref.read(bleServiceProvider);
    }).listen((bleState) {
      for (final d in bleState.devices) {
        _record(d.id, 'BLE', d.name.isNotEmpty ? d.name : 'Unknown BLE', d.rssi);
      }
    }) as StreamSubscription<BleScanState>?;

    // Cell
    final cellSvc = ref.read(cellServiceProvider);
    cellSvc.start();
    _cellSub = cellSvc.cellsStream.listen((cells) {
      for (final c in cells) {
        final tid = '${c.mcc}-${c.mnc}-${c.ci ?? c.cid ?? 0}';
        _record(tid, 'Cell', 'Tower $tid', c.dbm);
      }
    });

    // Periodic save
    _saveTimer = Timer.periodic(const Duration(seconds: 30), (_) => _save());
  }

  void _record(String id, String type, String label, int rssi) {
    final now = DateTime.now();
    final entries = Map<String, SignalMemoryEntry>.from(state.entries);

    if (entries.containsKey(id)) {
      final e = entries[id]!;
      e.seenCount++;
      e.lastSeen = now;
      if (e.sightingTimes.length >= 50) e.sightingTimes.removeAt(0);
      e.sightingTimes.add(now);

      // Auto-elevate threat level based on frequency
      if (e.seenCount >= 10 && e.threatLevel == ThreatLevel.unknown) {
        e.threatLevel = ThreatLevel.suspicious;
        e.note = 'Seen ${e.seenCount}× — auto-flagged suspicious';
      }
      if (e.seenCount >= 30 && e.threatLevel == ThreatLevel.suspicious) {
        e.threatLevel = ThreatLevel.threat;
        e.note = 'Seen ${e.seenCount}× across sessions — threat profile';
      }
    } else {
      entries[id] = SignalMemoryEntry(
        id: id, type: type, label: label,
        firstRssi: rssi, peakRssi: rssi,
        firstSeen: now, lastSeen: now, seenCount: 1,
        sightingTimes: [now],
      );
    }

    state = state.copyWith(
      entries: entries,
      totalSightings: state.totalSightings + 1,
      lastUpdate: now,
    );
  }

  void stopTracking() {
    _bleSub?.cancel();
    _wifiSub?.cancel();
    _cellSub?.cancel();
    _saveTimer?.cancel();
    _save();
    state = state.copyWith(isTracking: false);
  }

  void setThreatLevel(String id, ThreatLevel level) {
    final entries = Map<String, SignalMemoryEntry>.from(state.entries);
    if (entries.containsKey(id)) {
      entries[id]!.threatLevel = level;
      state = state.copyWith(entries: entries);
      _save();
    }
  }

  void setNote(String id, String note) {
    final entries = Map<String, SignalMemoryEntry>.from(state.entries);
    if (entries.containsKey(id)) {
      entries[id]!.note = note;
      state = state.copyWith(entries: entries);
      _save();
    }
  }

  void clearAll() {
    state = const SignalMemoryState();
    SharedPreferences.getInstance().then((p) => p.remove(_kPrefsKey));
  }
}

final signalMemoryProvider =
    NotifierProvider<SignalMemoryService, SignalMemoryState>(
  () => SignalMemoryService(),
);
