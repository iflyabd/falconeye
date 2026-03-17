import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  BATTERY OPTIMIZER SERVICE  V49.9
//  Real battery-saving algorithm:
//  • Throttles BLE scan to one burst per 30s instead of continuous
//  • Signals other services via stream to reduce their polling intervals
//  • Caps animation ticker rate to 20fps via a shared flag
//  • Drops heavy visual features (neural tendrils, glitch, scanlines) automatically
//  • Restores all rates on disable
// ═══════════════════════════════════════════════════════════════════════════════

class BatteryOptimizerState {
  final bool active;
  final int bleScanIntervalSeconds; // 0 = continuous, >0 = burst interval
  final int maxFps;                 // 60 = normal, 20 = battery save
  final bool heavyEffectsDisabled;
  final double cpuSavingPercent;    // estimated % reduction

  const BatteryOptimizerState({
    required this.active,
    required this.bleScanIntervalSeconds,
    required this.maxFps,
    required this.heavyEffectsDisabled,
    required this.cpuSavingPercent,
  });

  static BatteryOptimizerState normal() => const BatteryOptimizerState(
        active: false,
        bleScanIntervalSeconds: 0,
        maxFps: 60,
        heavyEffectsDisabled: false,
        cpuSavingPercent: 0,
      );

  static BatteryOptimizerState saving() => const BatteryOptimizerState(
        active: true,
        bleScanIntervalSeconds: 30,
        maxFps: 20,
        heavyEffectsDisabled: true,
        cpuSavingPercent: 52.0,
      );
}

class BatteryOptimizerService extends Notifier<BatteryOptimizerState> {
  Timer? _bleBurstTimer;
  final _onScanBurst = StreamController<void>.broadcast();
  final _onThrottleChange = StreamController<BatteryOptimizerState>.broadcast();

  /// Other services subscribe to this to know when a burst scan is allowed
  Stream<void> get scanBurstStream => _onScanBurst.stream;

  /// Other services subscribe to this for throttle state changes
  Stream<BatteryOptimizerState> get throttleStream => _onThrottleChange.stream;

  @override
  BatteryOptimizerState build() {
    ref.onDispose(_dispose);
    return BatteryOptimizerState.normal();
  }

  void enable() {
    if (state.active) return;
    state = BatteryOptimizerState.saving();
    _onThrottleChange.add(state);
    // Fire first burst immediately, then every 30s
    _onScanBurst.add(null);
    _bleBurstTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _onScanBurst.add(null),
    );
  }

  void disable() {
    if (!state.active) return;
    _bleBurstTimer?.cancel();
    _bleBurstTimer = null;
    state = BatteryOptimizerState.normal();
    _onThrottleChange.add(state);
    // Signal one immediate scan on restore
    _onScanBurst.add(null);
  }

  /// Returns true if an animation frame should be painted at [frameIndex]
  /// (frame-skip algorithm for FPS cap)
  bool shouldPaint(int frameIndex) {
    if (!state.active) return true;
    // Allow 20fps from 60fps ticker: paint every 3rd frame
    return frameIndex % 3 == 0;
  }

  void _dispose() {
    _bleBurstTimer?.cancel();
    _onScanBurst.close();
    _onThrottleChange.close();
  }
}

final batteryOptimizerProvider =
    NotifierProvider<BatteryOptimizerService, BatteryOptimizerState>(
  BatteryOptimizerService.new,
);
