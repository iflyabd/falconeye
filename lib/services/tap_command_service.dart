import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  TAP COMMAND SERVICE  V49.9
//  Physical gesture recognition via accelerometer — zero microphone needed.
//  Implements:
//    • DOUBLE-TAP  (2 impact spikes > 18 m/s² in < 600ms) → burst scan trigger
//    • TRIPLE-TAP  (3 impact spikes > 18 m/s² in < 800ms) → cycle vision mode
//    • FIRM SHAKE  (sustained jerk > 22 m/s² for > 300ms)  → stealth toggle
//
//  Used by:
//    FKey.voiceActivatedScan → enables double-tap burst scan
//    FKey.voiceCommands      → enables triple-tap + shake commands
// ═══════════════════════════════════════════════════════════════════════════════

enum TapCommand {
  doubleTap,  // burst scan
  tripleTap,  // cycle vision mode
  shake,      // stealth toggle
}

class TapCommandState {
  final bool voiceActivatedScan; // double-tap scan enabled
  final bool voiceCommands;      // triple-tap + shake enabled
  final TapCommand? lastCommand;
  final DateTime? lastCommandTime;
  final int burstScansTriggered;

  const TapCommandState({
    required this.voiceActivatedScan,
    required this.voiceCommands,
    this.lastCommand,
    this.lastCommandTime,
    required this.burstScansTriggered,
  });

  static TapCommandState initial() => const TapCommandState(
        voiceActivatedScan: false,
        voiceCommands: false,
        burstScansTriggered: 0,
      );

  TapCommandState copyWith({
    bool? voiceActivatedScan,
    bool? voiceCommands,
    TapCommand? lastCommand,
    DateTime? lastCommandTime,
    int? burstScansTriggered,
  }) =>
      TapCommandState(
        voiceActivatedScan: voiceActivatedScan ?? this.voiceActivatedScan,
        voiceCommands: voiceCommands ?? this.voiceCommands,
        lastCommand: lastCommand ?? this.lastCommand,
        lastCommandTime: lastCommandTime ?? this.lastCommandTime,
        burstScansTriggered: burstScansTriggered ?? this.burstScansTriggered,
      );
}

class TapCommandService extends Notifier<TapCommandState> {
  StreamSubscription<AccelerometerEvent>? _sub;

  // Impact detection state
  final List<int> _tapTimestamps = []; // epoch ms
  static const _tapThreshold = 18.0;  // m/s²
  static const _shakeThreshold = 22.0; // m/s²
  static const _shakeMinDurationMs = 300;
  int? _shakeStartMs;
  bool _inImpact = false; // debounce: ignore re-entry during same tap

  // Stream for other services to react to commands
  final _commandStream = StreamController<TapCommand>.broadcast();
  Stream<TapCommand> get commands => _commandStream.stream;

  @override
  TapCommandState build() {
    ref.onDispose(_dispose);
    return TapCommandState.initial();
  }

  void enableVoiceActivatedScan() {
    state = state.copyWith(voiceActivatedScan: true);
    _ensureListening();
  }

  void disableVoiceActivatedScan() {
    state = state.copyWith(voiceActivatedScan: false);
    _maybeStop();
  }

  void enableVoiceCommands() {
    state = state.copyWith(voiceCommands: true);
    _ensureListening();
  }

  void disableVoiceCommands() {
    state = state.copyWith(voiceCommands: false);
    _maybeStop();
  }

  bool get _needsListening => state.voiceActivatedScan || state.voiceCommands;

  void _ensureListening() {
    if (_sub != null) return;
    _sub = accelerometerEventStream().listen(_onAccel, onError: (_) {});
  }

  void _maybeStop() {
    if (!_needsListening) {
      _sub?.cancel();
      _sub = null;
    }
  }

  void _onAccel(AccelerometerEvent e) {
    // Subtract gravity estimate (9.81 on z at rest) for impact magnitude
    final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final impact = (mag - 9.81).abs(); // deviation from 1g = linear acceleration

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // ── SHAKE DETECTION ─────────────────────────────────────────────────────
    if (state.voiceCommands) {
      if (impact > _shakeThreshold) {
        _shakeStartMs ??= nowMs;
        final dur = nowMs - _shakeStartMs!;
        if (dur >= _shakeMinDurationMs) {
          _fire(TapCommand.shake);
          _shakeStartMs = null;
        }
      } else {
        if (impact < 5.0) _shakeStartMs = null; // reset on calm
      }
    }

    // ── TAP IMPACT DETECTION ─────────────────────────────────────────────────
    if (impact > _tapThreshold) {
      if (_inImpact) return; // debounce within same impact
      _inImpact = true;
      _tapTimestamps.add(nowMs);
      // Keep only last 3 taps
      while (_tapTimestamps.length > 3) _tapTimestamps.removeAt(0);

      _classifyTaps(nowMs);
    } else if (impact < 5.0) {
      _inImpact = false; // back to rest — next spike is a new tap
    }
  }

  void _classifyTaps(int nowMs) {
    final ts = _tapTimestamps;
    if (ts.length >= 3) {
      // Triple-tap: all 3 within 800ms
      if ((ts.last - ts[ts.length - 3]) <= 800 && state.voiceCommands) {
        _fire(TapCommand.tripleTap);
        _tapTimestamps.clear();
        return;
      }
    }
    if (ts.length >= 2) {
      // Double-tap: last 2 within 600ms
      final gap = ts.last - ts[ts.length - 2];
      if (gap >= 50 && gap <= 600) {
        if (state.voiceActivatedScan) {
          _fire(TapCommand.doubleTap);
        } else if (state.voiceCommands) {
          // voiceCommands also handles double-tap if voiceActivatedScan is off
          _fire(TapCommand.doubleTap);
        }
        // Don't clear — wait to see if triple arrives
      }
    }
  }

  void _fire(TapCommand cmd) {
    // Debounce: don't fire same command within 1.5s
    final now = DateTime.now();
    if (state.lastCommand == cmd &&
        state.lastCommandTime != null &&
        now.difference(state.lastCommandTime!).inMilliseconds < 1500) return;

    _commandStream.add(cmd);
    state = state.copyWith(
      lastCommand: cmd,
      lastCommandTime: now,
      burstScansTriggered: cmd == TapCommand.doubleTap
          ? state.burstScansTriggered + 1
          : state.burstScansTriggered,
    );
  }

  void _dispose() {
    _sub?.cancel();
    _commandStream.close();
  }
}

final tapCommandProvider =
    NotifierProvider<TapCommandService, TapCommandState>(TapCommandService.new);
