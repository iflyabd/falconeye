// ═══════════════════════════════════════════════════════════════════════════
//  FALCON EYE V42 — REAL BLE SERVICE
//  Real Bluetooth LE scanning with proper runtime-permission handling.
//  • Requests locationWhenInUse + bluetoothScan + bluetoothConnect at runtime
//  • No neverForLocation flag — required so Android lets BLE report positions
//  • Deduplicates by device-id, keeps freshest RSSI
//  • Auto-restarts every 15 s to refresh nearby devices
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleDevice {
  final String id;
  final String name;
  final int rssi;
  final bool connectable;

  const BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.connectable,
  });
}

class BleScanState {
  final bool scanning;
  final List<BleDevice> devices;
  final String status;

  const BleScanState({
    required this.scanning,
    required this.devices,
    required this.status,
  });

  BleScanState copyWith({bool? scanning, List<BleDevice>? devices, String? status}) =>
      BleScanState(
        scanning: scanning ?? this.scanning,
        devices: devices ?? this.devices,
        status: status ?? this.status,
      );

  static BleScanState initial() =>
      const BleScanState(scanning: false, devices: [], status: 'Idle');
}

class BleService extends Notifier<BleScanState> {
  final _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSub;
  Timer? _restartTimer;
  bool _started = false;

  @override
  BleScanState build() {
    ref.onDispose(() {
      _restartTimer?.cancel();
      _scanSub?.cancel();
    });
    return BleScanState.initial();
  }

  // ── Permission check ────────────────────────────────────────────────────
  Future<bool> _ensurePermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;

    // Request all three; each must be granted.
    final results = await [
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final denied = results.entries.where((e) => !e.value.isGranted).map((e) => e.key.toString()).toList();
    if (denied.isNotEmpty) {
      state = state.copyWith(status: 'Permissions denied: ${denied.join(", ")}');
      return false;
    }
    return true;
  }

  // ── Public start ────────────────────────────────────────────────────────
  Future<void> startScan() async {
    if (_started) return;
    _started = true;

    final ok = await _ensurePermissions();
    if (!ok) {
      _started = false;
      return;
    }

    await _doScan();

    // Restart every 15 s to keep the list fresh
    _restartTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _doScan();
    });
  }

  Future<void> _doScan() async {
    _scanSub?.cancel();
    state = state.copyWith(scanning: true, status: 'Scanning BLE…');
    try {
    _scanSub = _ble
        .scanForDevices(
          withServices: [],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          (device) {
            final existing = List<BleDevice>.from(state.devices);
            final idx = existing.indexWhere((d) => d.id == device.id);
            final bleDevice = BleDevice(
              id: device.id,
              name: device.name.isEmpty ? device.id.substring(0, 8) : device.name,
              rssi: device.rssi,
              connectable: device.connectable == Connectable.available,
            );
            if (idx >= 0) {
              existing[idx] = bleDevice;
            } else {
              existing.add(bleDevice);
            }
            // Sort by signal strength (strongest first)
            existing.sort((a, b) => b.rssi.compareTo(a.rssi));
            state = state.copyWith(
              devices: existing,
              status: 'BLE: ${existing.length} devices',
            );
          },
          onError: (dynamic e) {
            debugPrint('[BLE] scan error: $e');
            state = state.copyWith(scanning: false, status: 'BLE error: $e');
          },
          cancelOnError: false,
        );
    } on PlatformException catch (e) {
      state = state.copyWith(scanning: false,
          status: 'BT PERMISSION DENIED — Enable Bluetooth in Settings');
    } catch (e) {
      state = state.copyWith(scanning: false, status: 'BLE unavailable: $e');
    }

    // Stop individual scan after 10 s (restart timer will re-trigger)
    Future.delayed(const Duration(seconds: 10), () {
      _scanSub?.cancel();
      _scanSub = null;
      if (state.scanning) {
        state = state.copyWith(
          scanning: false,
          status: 'BLE: ${state.devices.length} devices found',
        );
      }
    });
  }

  void stopScan() {
    _started = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    _scanSub?.cancel();
    _scanSub = null;
    state = state.copyWith(
      scanning: false,
      status: 'Scan complete — ${state.devices.length} devices',
    );
  }
}

final bleServiceProvider = NotifierProvider<BleService, BleScanState>(() {
  return BleService();
});
