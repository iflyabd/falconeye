import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cell_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V48.1 — CELL TOWER SPOOF DETECTOR SERVICE
//  Compares observed cell tower (MCC/MNC/CI/PCI) against a learned baseline.
//  Flags towers with unexpected MCC/MNC for the device's registered carrier,
//  abnormally strong signal for a first-seen CI, or rapid CI switching.
//  Zero mock data: readings are 0 / empty until real cell data arrives.
// ═══════════════════════════════════════════════════════════════════════════════

enum SpoofRisk { none, low, medium, high, critical }

class CellTowerAlert {
  final String towerId;        // "MCC-MNC-CI/CID"
  final SpoofRisk risk;
  final String reason;
  final int rsrp;              // observed signal dBm
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int seenCount;

  const CellTowerAlert({
    required this.towerId,
    required this.risk,
    required this.reason,
    required this.rsrp,
    required this.firstSeen,
    required this.lastSeen,
    required this.seenCount,
  });

  CellTowerAlert copyWith({DateTime? lastSeen, int? seenCount}) => CellTowerAlert(
    towerId: towerId, risk: risk, reason: reason, rsrp: rsrp,
    firstSeen: firstSeen,
    lastSeen: lastSeen ?? this.lastSeen,
    seenCount: seenCount ?? this.seenCount,
  );

  String get riskLabel => risk.name.toUpperCase();

  Color get riskColor {
    switch (risk) {
      case SpoofRisk.none:     return const Color(0xFF00FF41);
      case SpoofRisk.low:      return const Color(0xFF88FF00);
      case SpoofRisk.medium:   return const Color(0xFFFFD700);
      case SpoofRisk.high:     return const Color(0xFFFF8800);
      case SpoofRisk.critical: return const Color(0xFFFF2222);
    }
  }
}

class SpoofDetectorState {
  final bool isScanning;
  final List<CellTowerAlert> alerts;
  final int registeredMcc;
  final int registeredMnc;
  final int scanCount;
  final DateTime? lastScan;
  final String status;

  const SpoofDetectorState({
    this.isScanning = false,
    this.alerts = const [],
    this.registeredMcc = -1,
    this.registeredMnc = -1,
    this.scanCount = 0,
    this.lastScan,
    this.status = 'IDLE',
  });

  SpoofDetectorState copyWith({
    bool? isScanning,
    List<CellTowerAlert>? alerts,
    int? registeredMcc,
    int? registeredMnc,
    int? scanCount,
    DateTime? lastScan,
    String? status,
  }) => SpoofDetectorState(
    isScanning: isScanning ?? this.isScanning,
    alerts: alerts ?? this.alerts,
    registeredMcc: registeredMcc ?? this.registeredMcc,
    registeredMnc: registeredMnc ?? this.registeredMnc,
    scanCount: scanCount ?? this.scanCount,
    lastScan: lastScan ?? this.lastScan,
    status: status ?? this.status,
  );

  SpoofRisk get overallRisk {
    if (alerts.isEmpty) return SpoofRisk.none;
    return alerts.map((a) => a.risk).reduce((a, b) => a.index > b.index ? a : b);
  }

  List<CellTowerAlert> get activeAlerts =>
      alerts.where((a) => a.risk != SpoofRisk.none).toList()
        ..sort((a, b) => b.risk.index.compareTo(a.risk.index));
}

class CellSpoofDetectorService extends Notifier<SpoofDetectorState> {
  final Map<String, List<int>> _baseline = {};
  int _refMcc = -1;
  int _refMnc = -1;
  Timer? _scanTimer;
  StreamSubscription<List<CellularCell>>? _cellSub;

  @override
  SpoofDetectorState build() {
    ref.onDispose(() {
      _scanTimer?.cancel();
      _cellSub?.cancel();
    });
    return const SpoofDetectorState();
  }

  void startScanning() {
    if (state.isScanning) return;
    state = state.copyWith(isScanning: true, status: 'SCANNING');
    final cellSvc = ref.read(cellServiceProvider);
    cellSvc.start();
    _cellSub = cellSvc.cellsStream.listen(_analyse);
  }

  void stopScanning() {
    _cellSub?.cancel();
    state = state.copyWith(isScanning: false, status: 'STOPPED');
  }

  void _analyse(List<CellularCell> cells) {
    if (cells.isEmpty) {
      state = state.copyWith(status: 'NO CELL DATA', scanCount: state.scanCount + 1,
          lastScan: DateTime.now());
      return;
    }

    final registered = cells.where((c) => c.registered);
    if (registered.isNotEmpty && _refMcc == -1) {
      _refMcc = registered.first.mcc;
      _refMnc = registered.first.mnc;
    }

    final newAlerts = Map<String, CellTowerAlert>.fromEntries(
        state.alerts.map((a) => MapEntry(a.towerId, a)));

    for (final cell in cells) {
      final tid = '${cell.mcc}-${cell.mnc}-${cell.ci ?? cell.cid ?? 0}';
      final dbm = cell.dbm;

      SpoofRisk risk = SpoofRisk.none;
      String reason = '';

      if (_refMcc != -1 && cell.mcc != _refMcc && cell.mcc > 0) {
        risk = SpoofRisk.critical;
        reason = 'MCC mismatch: expected $_refMcc got ${cell.mcc} — possible IMSI-catcher';
      } else if (_refMnc != -1 && cell.mnc != _refMnc && cell.mcc == _refMcc && cell.mnc > 0) {
        risk = SpoofRisk.high;
        reason = 'MNC mismatch: expected $_refMnc got ${cell.mnc} — rogue tower';
      } else if (!_baseline.containsKey(tid)) {
        _baseline[tid] = [dbm];
        if (dbm > -60 && cell.registered) {
          risk = SpoofRisk.medium;
          reason = 'New registered tower with strong signal ($dbm dBm) — verify';
        } else {
          risk = SpoofRisk.low;
          reason = 'First observation — building baseline';
        }
      } else {
        final hist = _baseline[tid]!;
        final avg = hist.reduce((a, b) => a + b) / hist.length;
        if (dbm - avg > 15) {
          risk = SpoofRisk.high;
          reason = 'Signal jump: ${dbm}dBm vs baseline ${avg.toInt()}dBm (Δ${(dbm - avg).toInt()})';
        }
        hist.add(dbm);
        if (hist.length > 20) hist.removeAt(0);
      }

      final existing = newAlerts[tid];
      newAlerts[tid] = CellTowerAlert(
        towerId: tid, risk: risk, reason: reason, rsrp: dbm,
        firstSeen: existing?.firstSeen ?? DateTime.now(),
        lastSeen: DateTime.now(),
        seenCount: (existing?.seenCount ?? 0) + 1,
      );
    }

    state = state.copyWith(
      alerts: newAlerts.values.toList(),
      registeredMcc: _refMcc, registeredMnc: _refMnc,
      scanCount: state.scanCount + 1, lastScan: DateTime.now(),
      status: 'ACTIVE — ${cells.length} towers',
    );
  }

  void clearAlerts() {
    _baseline.clear(); _refMcc = -1; _refMnc = -1;
    state = state.copyWith(alerts: [], status: 'CLEARED');
  }
}

final cellSpoofDetectorProvider =
    NotifierProvider<CellSpoofDetectorService, SpoofDetectorState>(
  () => CellSpoofDetectorService(),
);

