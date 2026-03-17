// ═══════════════════════════════════════════════════════════════════════════════
// FALCON EYE — REAL SIGNAL ENGINE v42
// Fuses REAL data: BLE RSSI, WiFi (root shell), Cellular RSSI, IMU orientation.
// Physics: log-distance path loss → distance, AoA via IMU → bearing.
// Kalman filter on RSSI, variance → motion detection.
//
// KEY FIXES v42:
//  - No BLE restart loop on permission failure
//  - Proper Android 12+ permission check BEFORE scanning
//  - Cell data read without location permission (READ_PHONE_STATE)
//  - Passive WiFi via /proc/net/wireless (no root needed)
//  - BLE only starts if BOTH bluetoothScan + location are granted
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:process_run/shell.dart';

// ─── Data models ────────────────────────────────────────────────────────────

class SignalSource {
  final String id;
  final String type;        // 'BLE' | 'WiFi' | 'Cell'
  final String label;
  final double rssi;        // Kalman-smoothed dBm
  final double rawRssi;     // last raw dBm
  final double x, y, z;    // meters (X=E, Y=up, Z=S)
  final double distance;    // meters
  final double azimuth;     // radians
  final double elevation;   // radians
  final double confidence;  // 0–1
  final DateTime lastSeen;
  final bool isMoving;
  final double rssiVariance;
  final int sampleCount;
  final String? extraInfo;

  const SignalSource({
    required this.id, required this.type, required this.label,
    required this.rssi, required this.rawRssi,
    required this.x, required this.y, required this.z,
    required this.distance, required this.azimuth, required this.elevation,
    required this.confidence, required this.lastSeen,
    this.isMoving = false, this.rssiVariance = 0,
    this.sampleCount = 0, this.extraInfo,
  });
}

class DeviceOrientation {
  final double roll, pitch, yaw;
  const DeviceOrientation({this.roll = 0, this.pitch = 0, this.yaw = 0});
}

class EnvironmentState {
  final List<SignalSource> sources;
  final DeviceOrientation orientation;
  final bool bleScanning;
  final bool wifiScanning;
  final bool cellActive;
  final bool hasRoot;
  final DateTime lastUpdate;
  final String statusMsg;
  final List<String> log;
  final Map<String, List<double>> rssiHistory;
  // Permission state
  final bool permLocationGranted;
  final bool permBleGranted;
  final bool permPhoneGranted;

  const EnvironmentState({
    this.sources = const [],
    this.orientation = const DeviceOrientation(),
    this.bleScanning = false,
    this.wifiScanning = false,
    this.cellActive = false,
    this.hasRoot = false,
    required this.lastUpdate,
    this.statusMsg = '',
    this.log = const [],
    this.rssiHistory = const {},
    this.permLocationGranted = false,
    this.permBleGranted = false,
    this.permPhoneGranted = false,
  });

  EnvironmentState copyWith({
    List<SignalSource>? sources, DeviceOrientation? orientation,
    bool? bleScanning, bool? wifiScanning, bool? cellActive, bool? hasRoot,
    DateTime? lastUpdate, String? statusMsg, List<String>? log,
    Map<String, List<double>>? rssiHistory,
    bool? permLocationGranted, bool? permBleGranted, bool? permPhoneGranted,
  }) => EnvironmentState(
    sources: sources ?? this.sources,
    orientation: orientation ?? this.orientation,
    bleScanning: bleScanning ?? this.bleScanning,
    wifiScanning: wifiScanning ?? this.wifiScanning,
    cellActive: cellActive ?? this.cellActive,
    hasRoot: hasRoot ?? this.hasRoot,
    lastUpdate: lastUpdate ?? this.lastUpdate,
    statusMsg: statusMsg ?? this.statusMsg,
    log: log ?? this.log,
    rssiHistory: rssiHistory ?? this.rssiHistory,
    permLocationGranted: permLocationGranted ?? this.permLocationGranted,
    permBleGranted: permBleGranted ?? this.permBleGranted,
    permPhoneGranted: permPhoneGranted ?? this.permPhoneGranted,
  );
}

// ─── Physics helpers ─────────────────────────────────────────────────────────

double rssiToDistance(double rssi, {double txPower = -59.0, double n = 2.7}) {
  if (rssi >= 0) return 0.5;
  return math.pow(10.0, (txPower - rssi) / (10.0 * n)).toDouble().clamp(0.3, 80.0);
}

class _Kalman {
  double _x, _p;
  final double q, r;
  _Kalman({double init = -70, this.q = 0.8, this.r = 5.0}) : _x = init, _p = 1.0;
  double update(double z) {
    _p += q;
    final k = _p / (_p + r);
    _x += k * (z - _x);
    _p *= (1 - k);
    return _x;
  }
  double get value => _x;
}

class _AoaTracker {
  final _s = <({double rssi, double yaw, double pitch})>[];
  static const _max = 40;
  void add(double rssi, double yaw, double pitch) {
    if (_s.length >= _max) _s.removeAt(0);
    _s.add((rssi: rssi, yaw: yaw, pitch: pitch));
  }
  double get azimuth   => _s.isEmpty ? 0 : _s.reduce((a, b) => a.rssi > b.rssi ? a : b).yaw;
  double get elevation => _s.isEmpty ? 0 : _s.reduce((a, b) => a.rssi > b.rssi ? a : b).pitch;
  int    get count     => _s.length;
}

double _variance(List<double> d) {
  if (d.length < 2) return 0;
  final m = d.reduce((a, b) => a + b) / d.length;
  return d.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / d.length;
}

// ─── Signal Engine ───────────────────────────────────────────────────────────
class SignalEngine extends Notifier<EnvironmentState> {
  static const _cellCh = MethodChannel('falcon_eye/cell');
  final _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _bleSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>?    _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  Timer? _cellTimer;
  Timer? _wifiTimer;
  Timer? _publishTimer;

  final _kalman   = <String, _Kalman>{};
  final _aoa      = <String, _AoaTracker>{};
  final _hist     = <String, List<double>>{};
  final _sources  = <String, SignalSource>{};
  final _log      = <String>[];

  double _roll = 0, _pitch = 0, _yaw = 0;
  int?   _lastGyroUs;
  bool   _hasRoot  = false;
  bool   _bleStarted = false;

  @override
  EnvironmentState build() {
    _boot();
    ref.onDispose(_dispose);
    return EnvironmentState(lastUpdate: DateTime.now(), statusMsg: 'Initializing...');
  }

  // ── Boot sequence ────────────────────────────────────────────────────────────
  Future<void> _boot() async {
    _addLog('Falcon Eye v42 starting...');
    _startIMU();
    _startCell();         // cell works without location permission
    _startWifiPassive();  // /proc/net/wireless – no permission needed
    _publishTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => _publish());

    // Check permissions and start BLE only if granted
    await _checkAndRequestPermissions();

    // Root check
    _hasRoot = await _checkRoot();
    _addLog(_hasRoot ? '[ROOT] Superuser confirmed – rooted WiFi scan enabled' : '[INFO] No root – passive mode only');
    if (_hasRoot) _startWifiRoot();
  }

  // ── Permission handling ──────────────────────────────────────────────────────
  Future<void> _checkAndRequestPermissions() async {
    // Check current status FIRST
    final locStatus  = await Permission.locationWhenInUse.status;
    final bleStatus  = await Permission.bluetoothScan.status;
    final phoneStat  = await Permission.phone.status;

    final locOk  = locStatus.isGranted;
    final bleOk  = bleStatus.isGranted || bleStatus.isLimited;
    final phoneOk = phoneStat.isGranted;

    state = state.copyWith(
      permLocationGranted: locOk,
      permBleGranted: bleOk,
      permPhoneGranted: phoneOk,
    );

    _addLog('Permissions: Location=${locStatus.name} BLE=${bleStatus.name} Phone=${phoneStat.name}');

    if (!locOk || !bleOk) {
      _addLog('Requesting Location + BLE permissions...');
      // Request all at once
      final results = await [
        Permission.locationWhenInUse,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
        Permission.phone,
      ].request();

      final newLocOk = results[Permission.locationWhenInUse]?.isGranted ?? false;
      final newBleOk = results[Permission.bluetoothScan]?.isGranted ?? false;
      final newPhoneOk = results[Permission.phone]?.isGranted ?? false;

      state = state.copyWith(
        permLocationGranted: newLocOk,
        permBleGranted: newBleOk,
        permPhoneGranted: newPhoneOk,
      );

      _addLog('After request: Location=$newLocOk BLE=$newBleOk Phone=$newPhoneOk');

      if (newLocOk && newBleOk) {
        _startBLE();
      } else {
        _addLog('[WARN] BLE scan DISABLED – grant Location + Bluetooth permissions in Settings');
        state = state.copyWith(statusMsg: 'Grant Location + Bluetooth in Settings to enable BLE scan');
      }
    } else {
      _addLog('Permissions already granted – starting BLE');
      _startBLE();
    }
  }

  // ── Root ─────────────────────────────────────────────────────────────────────
  Future<bool> _checkRoot() async {
    try {
      final r = await Shell(verbose: false).run('su -c "id"');
      return r.map((x) => x.stdout.toString()).join().contains('uid=0');
    } catch (_) { return false; }
  }

  // ── IMU complementary filter ─────────────────────────────────────────────────
  void _startIMU() {
    try {
      _accelSub = accelerometerEventStream().listen((e) {
        final accRoll  = math.atan2(e.y, e.z);
        final accPitch = math.atan2(-e.x, math.sqrt(e.y * e.y + e.z * e.z));
        _roll  = 0.96 * _roll  + 0.04 * accRoll;
        _pitch = 0.96 * _pitch + 0.04 * accPitch;
      }, onError: (_) {});
    } catch (_) {}

    try {
      _gyroSub = gyroscopeEventStream().listen((e) {
        final now = DateTime.now().microsecondsSinceEpoch;
        if (_lastGyroUs != null) {
          final dt = (now - _lastGyroUs!) / 1e6;
          if (dt > 0 && dt < 0.1) {
            _roll  += e.x * dt;
            _pitch += e.y * dt;
            _yaw   += e.z * dt;
          }
        }
        _lastGyroUs = now;
      }, onError: (_) {});
    } catch (_) {}

    try {
      _magSub = magnetometerEventStream().listen((e) {
        final cosR = math.cos(_roll),  sinR = math.sin(_roll);
        final cosP = math.cos(_pitch), sinP = math.sin(_pitch);
        final mx2 = e.x * cosP + e.z * sinP;
        final my2 = e.x * sinR * sinP + e.y * cosR - e.z * sinR * cosP;
        final magYaw = math.atan2(-my2, mx2);
        _yaw = 0.98 * _yaw + 0.02 * magYaw;
      }, onError: (_) {});
    } catch (_) {}
  }

  // ── BLE ──────────────────────────────────────────────────────────────────────
  void _startBLE() {
    if (_bleStarted) return; // NEVER restart in a loop
    _bleStarted = true;
    _addLog('Starting BLE scan...');
    try {
      _bleSub?.cancel();
      _bleSub = _ble.scanForDevices(withServices: []).listen(
        (d) {
          final name = d.name.isNotEmpty ? d.name : 'BLE-${d.id.substring(0, 8)}';
          _ingest(id: 'ble_${d.id}', type: 'BLE', label: name,
              rawRssi: d.rssi.toDouble(), txPower: -59.0);
        },
        onError: (e) {
          // Log ONCE — do NOT restart
          _addLog('[BLE] Scan error: $e');
          _bleStarted = false; // allow manual retry
          state = state.copyWith(bleScanning: false);
        },
        cancelOnError: false, // keep stream alive on single errors
      );
      state = state.copyWith(bleScanning: true, statusMsg: 'BLE scanning');
    } catch (e) {
      _addLog('[BLE] Failed to start: $e');
      _bleStarted = false;
    }
  }

  // ── Cell ─────────────────────────────────────────────────────────────────────
  void _startCell() {
    _cellTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollCell());
    _pollCell();
  }

  Future<void> _pollCell() async {
    try {
      final result = await _cellCh.invokeMethod<List>('getCellInfo');
      if (result == null || result.isEmpty) return;
      for (final raw in result) {
        final c    = Map<String, dynamic>.from(raw as Map);
        final type = c['type'] as String? ?? 'CELL';
        final ci   = c['ci'] ?? c['cid'] ?? c['pci'] ?? 0;
        final mcc  = c['mcc']?.toString() ?? '';
        final mnc  = c['mnc']?.toString() ?? '';
        final dbm  = ((c['dbm'] ?? c['rsrp'] ?? c['rssi'] ?? -100) as num).toDouble();
        final band = c['band']?.toString() ?? c['earfcn']?.toString() ?? '';
        _ingest(
          id: 'cell_${type}_$ci', type: 'Cell',
          label: '$type${mcc.isNotEmpty ? " $mcc-$mnc" : ""} CI:$ci',
          rawRssi: dbm, txPower: -70.0,
          extraInfo: band.isNotEmpty ? 'B$band' : null,
        );
      }
      state = state.copyWith(cellActive: true);
    } catch (e) {
      // Cell channel may not be available on all devices
      if (kDebugMode) debugPrint('[Cell] $e');
    }
  }

  // ── WiFi passive: /proc/net/wireless ─────────────────────────────────────────
  void _startWifiPassive() {
    _wifiTimer = Timer.periodic(const Duration(seconds: 8), (_) => _scanPassive());
    _scanPassive();
  }

  Future<void> _scanPassive() async {
    try {
      final shell = Shell(verbose: false);
      final r = await shell.run('cat /proc/net/wireless');
      final out = r.map((x) => x.stdout.toString()).join();
      int found = 0;
      for (final line in out.split('\n').skip(2)) {
        final p = line.trim().split(RegExp(r'\s+'));
        if (p.length < 4) continue;
        final iface = p[0].replaceAll(':', '');
        final raw   = double.tryParse(p[3].replaceAll('.', '')) ?? 0;
        final rssi  = raw > 0 ? raw - 256 : raw;
        if (rssi < -10) {
          _ingest(id: 'wifi_$iface', type: 'WiFi',
              label: 'WiFi($iface)', rawRssi: rssi, txPower: -30.0);
          found++;
        }
      }
      if (found > 0) state = state.copyWith(wifiScanning: true);
    } catch (_) {}
  }

  // ── WiFi root: iw dev wlan0 scan ─────────────────────────────────────────────
  void _startWifiRoot() {
    _addLog('[WiFi-root] Starting iw scan...');
    _wifiTimer?.cancel();
    _wifiTimer = Timer.periodic(const Duration(seconds: 10), (_) => _scanRoot());
    _scanRoot();
  }

  Future<void> _scanRoot() async {
    try {
      final shell = Shell(verbose: false);
      dynamic res;
      try {
        final r = await shell.run('su -c "iw dev wlan0 scan ap-force 2>/dev/null"');
        if (r.isNotEmpty) res = r.first;
      } catch (_) {
        try {
          final r = await shell.run('su -c "iwlist wlan0 scan 2>/dev/null"');
          if (r.isNotEmpty) res = r.first;
        } catch (_) {}
      }
      if (res != null) {
        final raw = res.stdout.toString();
        _parseIwScan(raw);
      }
      // Also get wpa_supplicant signal for current AP
      try {
        final r = await shell.run('su -c "wpa_cli -i wlan0 signal_poll 2>/dev/null"');
        _parseWpaPoll(r.map((x) => x.stdout.toString()).join());
      } catch (_) {}
      state = state.copyWith(wifiScanning: true);
    } catch (e) {
      _addLog('[WiFi-root] $e');
    }
  }

  void _parseIwScan(String raw) {
    String bssid = '', ssid = '';
    double sig = -100, freq = 2412;
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.startsWith('BSS ') && t.contains(':')) {
        if (bssid.isNotEmpty) _iwEntry(bssid, ssid, sig, freq);
        bssid = t.split(' ')[1].split('(')[0].trim();
        ssid = ''; sig = -100; freq = 2412;
      } else if (t.startsWith('SSID:')) {
        ssid = t.replaceFirst('SSID:', '').trim();
      } else if (t.startsWith('signal:')) {
        sig = double.tryParse(t.split(' ')[1]) ?? -100;
      } else if (t.startsWith('freq:')) {
        freq = double.tryParse(t.split(' ').last) ?? 2412;
      } else if (t.contains('Address:')) {
        bssid = t.split('Address:').last.trim();
        ssid = ''; sig = -100; freq = 2412;
      } else if (t.startsWith('ESSID:')) {
        ssid = t.replaceFirst('ESSID:', '').trim().replaceAll('"', '');
      } else if (t.contains('Signal level=')) {
        final m = RegExp(r'Signal level=(-?\d+)').firstMatch(t);
        if (m != null) sig = double.tryParse(m.group(1)!) ?? -100;
      } else if (t.contains('Frequency:')) {
        final m = RegExp(r'Frequency:([\d.]+)').firstMatch(t);
        if (m != null) freq = (double.tryParse(m.group(1)!) ?? 2.4) * 1000;
      }
    }
    if (bssid.isNotEmpty) _iwEntry(bssid, ssid, sig, freq);
  }

  void _iwEntry(String bssid, String ssid, double sig, double freq) {
    final band = freq >= 5000 ? '5GHz' : (freq >= 3000 ? '6GHz' : '2.4GHz');
    _ingest(id: 'wifi_$bssid', type: 'WiFi',
        label: ssid.isNotEmpty ? ssid : bssid,
        rawRssi: sig, txPower: -30.0, extraInfo: band);
  }

  void _parseWpaPoll(String raw) {
    double? rssi; double? freq;
    for (final l in raw.split('\n')) {
      if (l.startsWith('RSSI=')) rssi = double.tryParse(l.split('=')[1].trim());
      if (l.startsWith('FREQUENCY=')) freq = double.tryParse(l.split('=')[1].trim());
    }
    if (rssi != null) {
      final band = (freq != null && freq >= 5000) ? '5GHz' : '2.4GHz';
      _ingest(id: 'wifi_assoc', type: 'WiFi', label: 'Associated AP',
          rawRssi: rssi, txPower: -30.0, extraInfo: band);
    }
  }

  // ── Core ingest ──────────────────────────────────────────────────────────────
  void _ingest({
    required String id, required String type,
    required String label, required double rawRssi,
    double txPower = -59.0, String? extraInfo,
  }) {
    _kalman[id] ??= _Kalman(init: rawRssi);
    final smooth = _kalman[id]!.update(rawRssi);

    final hist = _hist.putIfAbsent(id, () => []);
    hist.add(rawRssi);
    if (hist.length > 25) hist.removeAt(0);
    final vari   = _variance(hist);
    final moving = vari > 6.0;

    _aoa[id] ??= _AoaTracker();
    _aoa[id]!.add(smooth, _yaw, _pitch);

    final n    = type == 'WiFi' ? 2.5 : type == 'Cell' ? 3.0 : 2.7;
    final dist = rssiToDistance(smooth, txPower: txPower, n: n);
    final az   = _aoa[id]!.azimuth;
    final el   = _aoa[id]!.elevation;

    final x = dist * math.cos(el) * math.sin(az);
    final y = dist * math.sin(el);
    final z = dist * math.cos(el) * math.cos(az);

    final sConf = (_aoa[id]!.count / 30.0).clamp(0.0, 1.0);
    final rConf = ((smooth + 100) / 70.0).clamp(0.0, 1.0);
    final conf  = sConf * 0.35 + rConf * 0.65;

    _sources[id] = SignalSource(
      id: id, type: type, label: label,
      rssi: smooth, rawRssi: rawRssi,
      x: x, y: y, z: z,
      distance: dist, azimuth: az, elevation: el,
      confidence: conf, lastSeen: DateTime.now(),
      isMoving: moving, rssiVariance: vari,
      sampleCount: _aoa[id]!.count,
      extraInfo: extraInfo,
    );
  }

  // ── Publish ──────────────────────────────────────────────────────────────────
  void _publish() {
    final now = DateTime.now();
    _sources.removeWhere((_, v) => now.difference(v.lastSeen).inSeconds > 30);
    final sorted = _sources.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    state = state.copyWith(
      sources: List.unmodifiable(sorted),
      orientation: DeviceOrientation(roll: _roll, pitch: _pitch, yaw: _yaw),
      hasRoot: _hasRoot,
      lastUpdate: now,
      rssiHistory: Map.unmodifiable(Map.from(_hist)),
    );
  }

  void _addLog(String msg) {
    if (kDebugMode) debugPrint('[FALCON] $msg');
    _log.add('[${DateTime.now().toString().substring(11, 19)}] $msg');
    if (_log.length > 200) _log.removeAt(0);
    state = state.copyWith(log: List.unmodifiable(_log), statusMsg: msg);
  }

  void _dispose() {
    _bleSub?.cancel(); _accelSub?.cancel(); _gyroSub?.cancel(); _magSub?.cancel();
    _cellTimer?.cancel(); _wifiTimer?.cancel(); _publishTimer?.cancel();
  }

  // ── Public ───────────────────────────────────────────────────────────────────
  void restartScan() {
    _sources.clear(); _kalman.clear(); _aoa.clear(); _hist.clear();
    _bleStarted = false;
    _bleSub?.cancel();
    _addLog('Scan restarted');
    _checkAndRequestPermissions();
  }

  Future<void> requestPermissionsAndRetry() async {
    _bleStarted = false;
    await _checkAndRequestPermissions();
  }
}

final signalEngineProvider = NotifierProvider<SignalEngine, EnvironmentState>(
  SignalEngine.new,
);
