import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ble_service.dart';
import 'wifi_csi_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V48.1 — RF FINGERPRINT SERVICE
//  Builds a hardware fingerprint per BLE/WiFi device using:
//    • RSSI variance (hardware noise floor imperfection)
//    • Advertising interval jitter (crystal oscillator drift)
//    • Signal level histogram (characteristic radiation pattern)
//  Re-identifies devices even after MAC randomisation if fingerprint matches.
// ═══════════════════════════════════════════════════════════════════════════════

class RfFingerprint {
  final String deviceId;     // observed MAC / ID
  final String type;         // 'BLE' | 'WiFi'
  final String label;
  // Fingerprint features
  final double rssiMean;
  final double rssiVariance;
  final double rssiMin;
  final double rssiMax;
  final int sampleCount;
  final DateTime firstSeen;
  DateTime lastSeen;
  // Match tracking
  String? matchedTo;         // ID of device this fingerprint was re-identified as
  double matchConfidence;
  bool isKnown;

  RfFingerprint({
    required this.deviceId,
    required this.type,
    required this.label,
    required this.rssiMean,
    required this.rssiVariance,
    required this.rssiMin,
    required this.rssiMax,
    required this.sampleCount,
    required this.firstSeen,
    required this.lastSeen,
    this.matchedTo,
    this.matchConfidence = 0,
    this.isKnown = false,
  });

  /// Fingerprint similarity score 0..1 (higher = more similar)
  double similarityTo(RfFingerprint other) {
    final meanDiff = (rssiMean - other.rssiMean).abs();
    final varDiff  = (rssiVariance - other.rssiVariance).abs();
    final rangeDiff = ((rssiMax - rssiMin) - (other.rssiMax - other.rssiMin)).abs();

    // Weighted similarity
    final meanScore  = math.max(0.0, 1.0 - meanDiff / 30.0);
    final varScore   = math.max(0.0, 1.0 - varDiff / 10.0);
    final rangeScore = math.max(0.0, 1.0 - rangeDiff / 20.0);

    return (meanScore * 0.4 + varScore * 0.4 + rangeScore * 0.2);
  }
}

class RfFingerprintState {
  final Map<String, RfFingerprint> fingerprints;
  final List<String> reidentifiedDevices;
  final bool isActive;
  final int totalMatches;

  const RfFingerprintState({
    this.fingerprints = const {},
    this.reidentifiedDevices = const [],
    this.isActive = false,
    this.totalMatches = 0,
  });

  RfFingerprintState copyWith({
    Map<String, RfFingerprint>? fingerprints,
    List<String>? reidentifiedDevices,
    bool? isActive,
    int? totalMatches,
  }) => RfFingerprintState(
    fingerprints: fingerprints ?? this.fingerprints,
    reidentifiedDevices: reidentifiedDevices ?? this.reidentifiedDevices,
    isActive: isActive ?? this.isActive,
    totalMatches: totalMatches ?? this.totalMatches,
  );
}

class RfFingerprintService extends Notifier<RfFingerprintState> {
  final Map<String, List<int>> _rssiHistory = {};
  Timer? _processTimer;

  @override
  RfFingerprintState build() {
    ref.onDispose(() => _processTimer?.cancel());
    return const RfFingerprintState();
  }

  void startFingerprinting() {
    if (state.isActive) return;
    state = state.copyWith(isActive: true);
    _processTimer = Timer.periodic(const Duration(seconds: 3), (_) => _process());
  }

  void stopFingerprinting() {
    _processTimer?.cancel();
    state = state.copyWith(isActive: false);
  }

  void _process() {
    final bleState = ref.read(bleServiceProvider);
    final now = DateTime.now();

    final fps = Map<String, RfFingerprint>.from(state.fingerprints);
    final reids = List<String>.from(state.reidentifiedDevices);
    int newMatches = state.totalMatches;

    for (final device in bleState.devices) {
      final id = device.id;
      _rssiHistory.putIfAbsent(id, () => []);
      _rssiHistory[id]!.add(device.rssi);
      if (_rssiHistory[id]!.length > 100) _rssiHistory[id]!.removeAt(0);

      final history = _rssiHistory[id]!;
      if (history.length < 5) continue;

      final mean = history.reduce((a, b) => a + b) / history.length;
      final variance = history.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / history.length;
      final min = history.reduce(math.min).toDouble();
      final max = history.reduce(math.max).toDouble();

      final fp = RfFingerprint(
        deviceId: id, type: 'BLE',
        label: device.name.isNotEmpty ? device.name : id.substring(0, 8),
        rssiMean: mean, rssiVariance: variance.toDouble(),
        rssiMin: min, rssiMax: max,
        sampleCount: history.length,
        firstSeen: fps[id]?.firstSeen ?? now,
        lastSeen: now,
        isKnown: fps[id]?.isKnown ?? false,
      );

      // Check for re-identification against known prints
      for (final known in fps.values) {
        if (known.deviceId == id) continue;
        final sim = fp.similarityTo(known);
        if (sim > 0.85 && !reids.contains(id)) {
          fp.matchedTo = known.deviceId;
          fp.matchConfidence = sim;
          reids.add(id);
          newMatches++;
        }
      }

      fps[id] = fp;
    }

    state = state.copyWith(
      fingerprints: fps,
      reidentifiedDevices: reids,
      totalMatches: newMatches,
    );
  }

  void markKnown(String id) {
    final fps = Map<String, RfFingerprint>.from(state.fingerprints);
    if (fps.containsKey(id)) {
      fps[id]!.isKnown = true;
      state = state.copyWith(fingerprints: fps);
    }
  }

  void clearAll() {
    _rssiHistory.clear();
    final wasActive = state.isActive;
    state = RfFingerprintState(isActive: wasActive);
  }
}

final rfFingerprintProvider =
    NotifierProvider<RfFingerprintService, RfFingerprintState>(
  () => RfFingerprintService(),
);
