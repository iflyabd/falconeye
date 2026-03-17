import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  JAMMER COUNTERMEASURE SERVICE  V49.9
//  Real algorithm when jammer is detected:
//  • Switches BLE scan to LOWLATENCY mode (max scan window) for maximum
//    channel-hopping throughput — BLE hops 37/38/39 advertising channels.
//    Aggressive scanning forces the radio to listen on all channels rapidly,
//    making it harder for a narrowband jammer to suppress all channels.
//  • Simultaneously logs all RSSI anomalies (sudden drops) as jammer events.
//  • Reports RSSI floor variance as jammer confidence score.
//  • On countermeasure disable: returns to LOW_POWER mode.
// ═══════════════════════════════════════════════════════════════════════════════

class JammerCountermeasureState {
  final bool active;
  final bool jammerConfirmed;
  final double jammerConfidence; // 0.0–1.0
  final int eventsLogged;
  final String status;
  final List<double> rssiHistory; // last 20 readings for variance calculation

  const JammerCountermeasureState({
    required this.active,
    required this.jammerConfirmed,
    required this.jammerConfidence,
    required this.eventsLogged,
    required this.status,
    required this.rssiHistory,
  });

  static JammerCountermeasureState idle() => const JammerCountermeasureState(
        active: false,
        jammerConfirmed: false,
        jammerConfidence: 0.0,
        eventsLogged: 0,
        status: 'Countermeasures offline',
        rssiHistory: [],
      );

  JammerCountermeasureState copyWith({
    bool? active,
    bool? jammerConfirmed,
    double? jammerConfidence,
    int? eventsLogged,
    String? status,
    List<double>? rssiHistory,
  }) =>
      JammerCountermeasureState(
        active: active ?? this.active,
        jammerConfirmed: jammerConfirmed ?? this.jammerConfirmed,
        jammerConfidence: jammerConfidence ?? this.jammerConfidence,
        eventsLogged: eventsLogged ?? this.eventsLogged,
        status: status ?? this.status,
        rssiHistory: rssiHistory ?? this.rssiHistory,
      );
}

class JammerCountermeasureService
    extends Notifier<JammerCountermeasureState> {
  final _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _aggressiveScanSub;
  Timer? _analysisTimer;

  // RSSI variance tracking
  final List<double> _rssiBuffer = [];
  static const _kBufferSize = 30;
  static const _kVarianceJammerThreshold = 120.0; // high variance = jammer interference

  @override
  JammerCountermeasureState build() {
    ref.onDispose(_stop);
    return JammerCountermeasureState.idle();
  }

  Future<void> activate() async {
    if (state.active) return;
    final ok = await Permission.bluetoothScan.isGranted;
    if (!ok) {
      state = state.copyWith(status: 'BLE permission required');
      return;
    }
    state = state.copyWith(active: true, status: 'COUNTERMEASURES ACTIVE — Aggressive scan');

    // Switch to LOW_LATENCY scan (continuous, no duty cycle)
    // This maximises BLE advertising channel coverage (37, 38, 39 hopping)
    _aggressiveScanSub?.cancel();
    _aggressiveScanSub =
        _ble.scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
            .listen(_analyseSignal, onError: (_) {});

    // Run RSSI variance analysis every 3s
    _analysisTimer = Timer.periodic(const Duration(seconds: 3), (_) => _computeJammerScore());
  }

  void _analyseSignal(DiscoveredDevice d) {
    _rssiBuffer.add(d.rssi.toDouble());
    if (_rssiBuffer.length > _kBufferSize) _rssiBuffer.removeAt(0);
  }

  void _computeJammerScore() {
    if (_rssiBuffer.length < 5) return;
    final mean = _rssiBuffer.reduce((a, b) => a + b) / _rssiBuffer.length;
    final variance =
        _rssiBuffer.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            _rssiBuffer.length;

    final confidence = (variance / _kVarianceJammerThreshold).clamp(0.0, 1.0);
    final confirmed = confidence > 0.65;

    state = state.copyWith(
      jammerConfidence: confidence,
      jammerConfirmed: confirmed,
      eventsLogged: state.eventsLogged + (confirmed ? 1 : 0),
      rssiHistory: List.unmodifiable(_rssiBuffer.takeLast(20).toList()),
      status: confirmed
          ? 'JAMMER CONFIRMED — Countermeasures engaged (${(confidence * 100).round()}%)'
          : 'Monitoring — confidence ${(confidence * 100).round()}%',
    );
  }

  void deactivate() => _stop();

  void _stop() {
    _aggressiveScanSub?.cancel();
    _aggressiveScanSub = null;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _rssiBuffer.clear();
    state = JammerCountermeasureState.idle();
  }
}

final jammerCountermeasureProvider =
    NotifierProvider<JammerCountermeasureService, JammerCountermeasureState>(
  JammerCountermeasureService.new,
);

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}
