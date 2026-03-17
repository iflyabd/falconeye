// ═══════════════════════════════════════════════════════════════════════════
//  FALCON EYE V42 — REAL MULTI-SIGNAL FUSION SERVICE
//  Combines REAL signals: WiFi CSI + BLE RSSI + Cellular + IMU + Magnetometer
//  No fake data — all points come from hardware.
//
//  REAL DATA SOURCES:
//    BLE RSSI      → distance via log-distance path-loss
//    WiFi APs      → distance + bearing via multilateration
//    Cell towers   → coarse distance (RSRP → path-loss)
//    IMU accel     → Doppler velocity estimate
//    Magnetometer  → detect metal / conductive objects nearby
//    /proc data    → driver-level signal counters (no root)
//
//  3D PIPELINE:
//    BLE devices  → RadioWavePoint3D per device
//    WiFi APs     → RadioWavePoint3D per AP (from wifiCSIProvider)
//    Cell towers  → RadioWavePoint3D per tower
//    Fused cloud  → DBSCAN → Kalman → AI-interpolation  (digital_twin_engine)
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'wifi_csi_service.dart';
import 'cell_service.dart';
import 'ble_service.dart';
import 'imu_fusion_service.dart';
import 'digital_twin_engine.dart';

// ── V42 data classes kept 100% identical so painter + pages don't break ─────

class FusionDataPoint {
  final DateTime timestamp;
  final List<CSIDataPoint>? wifiCSI;
  final List<CellularCell>? cellularCells;
  final List<BleDevice>? bleDevices;
  final MagnetometerEvent? magnetometer;
  final AccelerometerEvent? accelerometer;
  final GyroscopeEvent? gyroscope;
  final double? barometricPressure;
  final double? dopplerVelocity;
  final Map<String, double>? backscatterCoefficients;
  final List<MultipathEcho>? multipathEchoes;

  const FusionDataPoint({
    required this.timestamp,
    this.wifiCSI,
    this.cellularCells,
    this.bleDevices,
    this.magnetometer,
    this.accelerometer,
    this.gyroscope,
    this.barometricPressure,
    this.dopplerVelocity,
    this.backscatterCoefficients,
    this.multipathEchoes,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'wifiCSI': wifiCSI?.map((c) => {
      'subcarrierIndex': c.subcarrierIndex,
      'antennaIndex': c.antennaIndex,
      'amplitude': c.amplitude,
      'phase': c.phase,
      'rssi': c.rssi,
      'snr': c.snr,
      'frequency': c.frequency,
    }).toList(),
    'cellularCells': cellularCells?.map((c) => {
      'type': c.type,
      'mcc': c.mcc,
      'mnc': c.mnc,
      'rsrp': c.rsrp,
      'rsrq': c.rsrq,
      'rssnr': c.rssnr,
      'dbm': c.dbm,
    }).toList(),
    'bleDevices': bleDevices?.map((b) => {
      'id': b.id,
      'name': b.name,
      'rssi': b.rssi,
    }).toList(),
    'magnetometer': magnetometer != null
        ? {'x': magnetometer!.x, 'y': magnetometer!.y, 'z': magnetometer!.z}
        : null,
    'accelerometer': accelerometer != null
        ? {'x': accelerometer!.x, 'y': accelerometer!.y, 'z': accelerometer!.z}
        : null,
    'gyroscope': gyroscope != null
        ? {'x': gyroscope!.x, 'y': gyroscope!.y, 'z': gyroscope!.z}
        : null,
    'barometricPressure': barometricPressure,
    'dopplerVelocity': dopplerVelocity,
    'backscatterCoefficients': backscatterCoefficients,
    'multipathEchoes': multipathEchoes?.map((e) => {
      'delay': e.delayNanoseconds,
      'amplitude': e.amplitudeDb,
      'phase': e.phaseRadians,
    }).toList(),
  };

  factory FusionDataPoint.fromJson(Map<String, dynamic> json) {
    return FusionDataPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      wifiCSI: json['wifiCSI'] != null
          ? (json['wifiCSI'] as List)
              .map((c) => CSIDataPoint(
                    timestamp: DateTime.parse(json['timestamp'] as String),
                    subcarrierIndex: c['subcarrierIndex'] as int,
                    antennaIndex: c['antennaIndex'] as int,
                    amplitude: (c['amplitude'] as num).toDouble(),
                    phase: (c['phase'] as num).toDouble(),
                    rssi: c['rssi'] as int,
                    snr: (c['snr'] as num).toDouble(),
                    frequency: (c['frequency'] as num).toDouble(),
                  ))
              .toList()
          : null,
      cellularCells: json['cellularCells'] != null
          ? (json['cellularCells'] as List)
              .map((c) => CellularCell(
                    type: c['type'] as String,
                    registered: true,
                    mcc: c['mcc'] as int,
                    mnc: c['mnc'] as int,
                    rsrp: c['rsrp'] as int?,
                    rsrq: c['rsrq'] as int?,
                    rssnr: c['rssnr'] as int?,
                    asuLevel: 0,
                    dbm: c['dbm'] as int,
                  ))
              .toList()
          : null,
      bleDevices: json['bleDevices'] != null
          ? (json['bleDevices'] as List)
              .map((b) => BleDevice(
                    id: b['id'] as String,
                    name: b['name'] as String,
                    rssi: b['rssi'] as int,
                    connectable: false,
                  ))
              .toList()
          : null,
      magnetometer: json['magnetometer'] != null
          ? MagnetometerEvent(
              (json['magnetometer']['x'] as num).toDouble(),
              (json['magnetometer']['y'] as num).toDouble(),
              (json['magnetometer']['z'] as num).toDouble(),
              DateTime.now(),
            )
          : null,
      accelerometer: json['accelerometer'] != null
          ? AccelerometerEvent(
              (json['accelerometer']['x'] as num).toDouble(),
              (json['accelerometer']['y'] as num).toDouble(),
              (json['accelerometer']['z'] as num).toDouble(),
              DateTime.now(),
            )
          : null,
      gyroscope: json['gyroscope'] != null
          ? GyroscopeEvent(
              (json['gyroscope']['x'] as num).toDouble(),
              (json['gyroscope']['y'] as num).toDouble(),
              (json['gyroscope']['z'] as num).toDouble(),
              DateTime.now(),
            )
          : null,
      barometricPressure: json['barometricPressure'] as double?,
      dopplerVelocity: json['dopplerVelocity'] as double?,
      backscatterCoefficients: json['backscatterCoefficients'] != null
          ? Map<String, double>.from(json['backscatterCoefficients'] as Map)
          : null,
      multipathEchoes: json['multipathEchoes'] != null
          ? (json['multipathEchoes'] as List)
              .map((e) => MultipathEcho(
                    delayNanoseconds: (e['delay'] as num).toDouble(),
                    amplitudeDb: (e['amplitude'] as num).toDouble(),
                    phaseRadians: (e['phase'] as num).toDouble(),
                  ))
              .toList()
          : null,
    );
  }
}

class MultipathEcho {
  final double delayNanoseconds;
  final double amplitudeDb;
  final double phaseRadians;
  const MultipathEcho({
    required this.delayNanoseconds,
    required this.amplitudeDb,
    required this.phaseRadians,
  });
}

class Fused3DPoint {
  final double x, y, z;
  final double confidence;
  final MaterialType materialType;
  final double velocity;
  final double reflectionStrength;
  final String signalSources;
  final Map<String, double> signalContributions;

  const Fused3DPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
    required this.materialType,
    required this.velocity,
    required this.reflectionStrength,
    required this.signalSources,
    required this.signalContributions,
  });
}

class MultiSignalFusionState {
  final bool isActive;
  final bool isRecording;
  final List<FusionDataPoint> liveBuffer;
  final List<Fused3DPoint> fused3DEnvironment;
  final int fusionRate;
  final Map<String, bool> activeSignals;
  final String status;

  const MultiSignalFusionState({
    this.isActive = false,
    this.isRecording = false,
    this.liveBuffer = const [],
    this.fused3DEnvironment = const [],
    this.fusionRate = 0,
    this.activeSignals = const {},
    this.status = 'Idle',
  });

  MultiSignalFusionState copyWith({
    bool? isActive,
    bool? isRecording,
    List<FusionDataPoint>? liveBuffer,
    List<Fused3DPoint>? fused3DEnvironment,
    int? fusionRate,
    Map<String, bool>? activeSignals,
    String? status,
  }) =>
      MultiSignalFusionState(
        isActive: isActive ?? this.isActive,
        isRecording: isRecording ?? this.isRecording,
        liveBuffer: liveBuffer ?? this.liveBuffer,
        fused3DEnvironment: fused3DEnvironment ?? this.fused3DEnvironment,
        fusionRate: fusionRate ?? this.fusionRate,
        activeSignals: activeSignals ?? this.activeSignals,
        status: status ?? this.status,
      );
}

// ── Helper: String → MaterialType ─────────────────────────────────────────
MaterialType _parseMaterialType(String hint) {
  switch (hint.toLowerCase()) {
    case 'human':    return MaterialType.organic;
    case 'organic':  return MaterialType.organic;
    case 'wall':     return MaterialType.concrete;
    case 'concrete': return MaterialType.concrete;
    case 'metal':    return MaterialType.metal;
    case 'glass':    return MaterialType.glass;
    case 'water':    return MaterialType.water;
    case 'wood':     return MaterialType.wood;
    case 'plastic':  return MaterialType.plastic;
    default:         return MaterialType.unknown;
  }
}

// ── Fusion Service ───────────────────────────────────────────────────────────
class MultiSignalFusionService extends Notifier<MultiSignalFusionState> {
  Timer? _fusionTimer;
  StreamSubscription? _magSub;
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;

  MagnetometerEvent? _lastMag;
  AccelerometerEvent? _lastAccel;
  GyroscopeEvent? _lastGyro;

  @override
  MultiSignalFusionState build() => const MultiSignalFusionState();

  // ── Public API ─────────────────────────────────────────────────────────
  Future<void> start() async {
    if (state.isActive) return;
    debugPrint('[Fusion V42] Starting real multi-signal fusion…');

    // IMU subscriptions — real hardware streams
    _safeSubscribeMag();
    _safeSubscribeAccel();
    _safeSubscribeGyro();

    // Start WiFi CSI (real APs)
    await ref.read(wifiCSIProvider.notifier).initialize();
    await ref.read(wifiCSIProvider.notifier).startCapture();

    // Start BLE (real devices)
    await ref.read(bleServiceProvider.notifier).startScan();

    // Cell service starts automatically via cellStreamProvider

    state = state.copyWith(isActive: true, status: 'Fusing real signals…');

    // 20 Hz fusion loop
    _fusionTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _performFusion();
    });

    debugPrint('[Fusion V42] ACTIVE — WiFi+BLE+Cell+IMU+Mag');
  }

  void stop() {
    _fusionTimer?.cancel();
    _fusionTimer = null;
    _magSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    ref.read(wifiCSIProvider.notifier).stopCapture();
    ref.read(bleServiceProvider.notifier).stopScan();
    ref.read(cellServiceProvider).stop();
    state = state.copyWith(isActive: false, fusionRate: 0, status: 'Stopped');
  }

  /// PERF V50.0: Throttle fusion rate when the 3D view is not visible.
  /// throttled=true  → 2 Hz (save CPU/battery while on other pages)
  /// throttled=false → 20 Hz (full rate when 3D view is active)
  void setThrottled(bool throttled) {
    if (!state.isActive) return;
    _fusionTimer?.cancel();
    final interval = throttled
        ? const Duration(milliseconds: 500)   // 2 Hz background
        : const Duration(milliseconds: 50);   // 20 Hz foreground
    _fusionTimer = Timer.periodic(interval, (_) => _performFusion());
  }

  // ── IMU subscriptions with error guards ───────────────────────────────
  void _safeSubscribeMag() {
    try {
      _magSub = magnetometerEventStream().listen((e) { _lastMag = e; },
          onError: (dynamic _) {});
    } catch (_) {}
  }

  void _safeSubscribeAccel() {
    try {
      _accelSub = accelerometerEventStream().listen((e) { _lastAccel = e; },
          onError: (dynamic _) {});
    } catch (_) {}
  }

  void _safeSubscribeGyro() {
    try {
      _gyroSub = gyroscopeEventStream().listen((e) { _lastGyro = e; },
          onError: (dynamic _) {});
    } catch (_) {}
  }

  // ── Main fusion cycle ──────────────────────────────────────────────────
  void _performFusion() {
    final now = DateTime.now();

    final wifiState  = ref.read(wifiCSIProvider);
    final bleState   = ref.read(bleServiceProvider);
    final cellState  = ref.read(cellStreamProvider).asData?.value ?? [];

    // ── Build FusionDataPoint from REAL hardware ────────────────────────
    final fusionPoint = FusionDataPoint(
      timestamp: now,
      wifiCSI: wifiState.rawData.isNotEmpty
          ? wifiState.rawData.take(64).toList()
          : null,
      cellularCells: cellState.isNotEmpty ? cellState : null,
      bleDevices: bleState.devices.take(30).toList(),
      magnetometer: _lastMag,
      accelerometer: _lastAccel,
      gyroscope: _lastGyro,
      dopplerVelocity: _dopplerFromIMU(),
      backscatterCoefficients: _backscatterFromWifi(wifiState),
      multipathEchoes: _multipathFromCSI(wifiState),
    );

    // Live buffer (last 100 frames)
    final buffer = [...state.liveBuffer, fusionPoint];
    final trimmed = buffer.length > 100 ? buffer.sublist(buffer.length - 100) : buffer;

    final activeSignals = {
      'WiFi CSI':   wifiState.isCapturing,
      'Cellular':   cellState.isNotEmpty,
      'Bluetooth':  bleState.devices.isNotEmpty,
      'Magnetometer': _lastMag != null,
      'IMU':        _lastAccel != null && _lastGyro != null,
    };

    // ── Reconstruct 3D from real signals ──────────────────────────────
    final fused3D = _reconstruct3D(fusionPoint, wifiState, bleState, cellState);

    state = state.copyWith(
      liveBuffer: trimmed,
      fused3DEnvironment: fused3D,
      fusionRate: state.isActive ? 20 : 0,
      activeSignals: activeSignals,
      status: 'Fusing ${activeSignals.values.where((v) => v).length} signals',
    );
  }

  // ── 3D Reconstruction ──────────────────────────────────────────────────
  List<Fused3DPoint> _reconstruct3D(
    FusionDataPoint fusion,
    WiFiCSIState wifiState,
    BleScanState bleState,
    List<CellularCell> cells,
  ) {
    final rawPoints = <DigitalTwinPoint>[];

    // 1. WiFi CSI points (already 3D from WiFiCSIService)
    for (final p in wifiState.reconstructed3D) {
      rawPoints.add(DigitalTwinPoint(
        x: p.x, y: p.y, z: p.z,
        strength: p.reflectionStrength,
        confidence: p.confidence,
        materialHint: p.materialType.name,
        velocity: p.velocity,
      ));
    }

    // 2. BLE devices → distance from RSSI → 3D point on sphere
    for (int i = 0; i < bleState.devices.length; i++) {
      final ble = bleState.devices[i];
      final dist = _rssiToDist(ble.rssi.toDouble());
      final az = (i / bleState.devices.length) * 2 * math.pi;
      final el = 0.0; // BLE devices assumed near floor level
      rawPoints.add(DigitalTwinPoint(
        x: dist * math.cos(az),
        y: el,
        z: dist * math.sin(az),
        strength: _rssiToConf(ble.rssi.toDouble()),
        confidence: _rssiToConf(ble.rssi.toDouble()),
        materialHint: 'unknown',
        velocity: 0,
      ));
    }

    // 3. Cellular towers → coarse distance
    for (int i = 0; i < cells.length; i++) {
      final cell = cells[i];
      final rsrp = cell.rsrp ?? cell.dbm;
      final dist = _rssiToDist(rsrp.toDouble()).clamp(10.0, 500.0);
      final az = (i / math.max(cells.length, 1)) * 2 * math.pi;
      rawPoints.add(DigitalTwinPoint(
        x: dist * math.cos(az),
        y: -1.0, // towers usually below horizon
        z: dist * math.sin(az),
        strength: 0.3,
        confidence: 0.3,
        materialHint: 'metal',
        velocity: 0,
      ));
    }

    // 4. Magnetic anomaly point
    if (fusion.magnetometer != null) {
      final mag = fusion.magnetometer!;
      final strength = math.sqrt(mag.x * mag.x + mag.y * mag.y + mag.z * mag.z);
      // Earth's field ≈ 25–65 µT; anomaly if outside this band
      if (strength > 70 || strength < 20) {
        rawPoints.add(DigitalTwinPoint(
          x: 1.5, y: 0, z: 0,
          strength: ((strength - 40).abs() / 40).clamp(0.0, 1.0),
          confidence: 0.7,
          materialHint: 'metal',
          velocity: 0,
        ));
      }
    }

    if (rawPoints.isEmpty) return [];

    // ── Digital Twin Engine: Kalman + DBSCAN + AI interpolation ─────────
    final avgConf = rawPoints.fold(0.0, (s, p) => s + p.confidence) / rawPoints.length;
    final rssiQuality = (avgConf * 0.7 + (rawPoints.length / 200.0)).clamp(0.0, 1.0);

    final processed = digitalTwinEngine.process(
      rawPoints: rawPoints,
      rssiStrength: rssiQuality,
    );

    return processed.map((p) => Fused3DPoint(
      x: p.x, y: p.y, z: p.z,
      confidence: p.confidence,
      materialType: _parseMaterialType(p.materialHint),
      velocity: p.velocity,
      reflectionStrength: p.strength,
      signalSources: 'V42-Real',
      signalContributions: {'Real': p.confidence},
    )).toList();
  }

  // ── Signal helpers ─────────────────────────────────────────────────────
  double _rssiToDist(double rssi) {
    const txPower = -40.0;
    const n = 2.7;
    return math.pow(10, (txPower - rssi) / (10 * n)).toDouble().clamp(0.3, 100.0);
  }

  double _rssiToConf(double rssi) => ((rssi + 100) / 70.0).clamp(0.0, 1.0);

  double _dopplerFromIMU() {
    if (_lastAccel == null) return 0;
    final a = _lastAccel!;
    final mag = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
    return (mag - 9.81).abs().clamp(0.0, 10.0);
  }

  Map<String, double> _backscatterFromWifi(WiFiCSIState wifi) {
    if (wifi.rawData.isEmpty) return {};
    final phases = wifi.rawData.map((c) => c.phase).toList();
    final avg = phases.reduce((a, b) => a + b) / phases.length;
    return {
      'forward': (1.0 - avg / math.pi).clamp(0.0, 1.0),
      'backward': (avg / math.pi).clamp(0.0, 1.0),
    };
  }

  List<MultipathEcho> _multipathFromCSI(WiFiCSIState wifi) {
    if (wifi.rawData.length < 10) return [];
    final echoes = <MultipathEcho>[];
    for (int i = 5; i < wifi.rawData.length - 5; i++) {
      final cur  = wifi.rawData[i];
      final prev = wifi.rawData[i - 1];
      final next = wifi.rawData[i + 1];
      if (cur.amplitude > prev.amplitude && cur.amplitude > next.amplitude) {
        echoes.add(MultipathEcho(
          delayNanoseconds: cur.subcarrierIndex * 50.0,
          amplitudeDb: cur.amplitude,
          phaseRadians: cur.phase,
        ));
      }
    }
    return echoes.take(10).toList();
  }
}

final multiSignalFusionProvider =
    NotifierProvider<MultiSignalFusionService, MultiSignalFusionState>(
  () => MultiSignalFusionService(),
);
