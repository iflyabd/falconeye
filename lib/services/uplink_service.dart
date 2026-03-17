import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UplinkSample {
  final int timestampMs;
  final int mobileTxBytes;
  final int mobileRxBytes;
  final int mobileTxPackets;
  final int mobileRxPackets;
  final int dataState; // TelephonyManager.DATA_* constants
  final int dataActivity; // TelephonyManager.DATA_ACTIVITY_*
  final int networkType; // TelephonyManager.NETWORK_TYPE_*
  final bool isDataEnabled;

  // Derived
  final double uplinkKbps; // computed from delta bytes
  final double downlinkKbps;

  UplinkSample({
    required this.timestampMs,
    required this.mobileTxBytes,
    required this.mobileRxBytes,
    required this.mobileTxPackets,
    required this.mobileRxPackets,
    required this.dataState,
    required this.dataActivity,
    required this.networkType,
    required this.isDataEnabled,
    required this.uplinkKbps,
    required this.downlinkKbps,
  });

  factory UplinkSample.fromMap(Map data, {UplinkSample? prev}) {
    final ts = (data['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
    final tx = (data['mobileTxBytes'] as int?) ?? 0;
    final rx = (data['mobileRxBytes'] as int?) ?? 0;
    final txP = (data['mobileTxPackets'] as int?) ?? 0;
    final rxP = (data['mobileRxPackets'] as int?) ?? 0;
    final ds = (data['dataState'] as int?) ?? -1;
    final da = (data['dataActivity'] as int?) ?? -1;
    final nt = (data['networkType'] as int?) ?? -1;
    final en = (data['isDataEnabled'] as bool?) ?? false;

    double upKbps = 0;
    double downKbps = 0;
    if (prev != null) {
      final dt = (ts - prev.timestampMs) / 1000.0;
      if (dt > 0) {
        upKbps = ((tx - prev.mobileTxBytes) * 8.0) / 1000.0 / dt;
        downKbps = ((rx - prev.mobileRxBytes) * 8.0) / 1000.0 / dt;
        if (upKbps < 0) upKbps = 0;
        if (downKbps < 0) downKbps = 0;
      }
    }

    return UplinkSample(
      timestampMs: ts,
      mobileTxBytes: tx,
      mobileRxBytes: rx,
      mobileTxPackets: txP,
      mobileRxPackets: rxP,
      dataState: ds,
      dataActivity: da,
      networkType: nt,
      isDataEnabled: en,
      uplinkKbps: upKbps,
      downlinkKbps: downKbps,
    );
  }
}

class UplinkService {
  static const _channel = MethodChannel('falcon_eye/uplink');
  final _controller = StreamController<UplinkSample>.broadcast();
  Timer? _timer;
  UplinkSample? _last;

  Stream<UplinkSample> get stream => _controller.stream;

  Future<void> start({Duration interval = const Duration(seconds: 1)}) async {
    await _poll();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    try {
      final result = await _channel.invokeMethod('getUplinkStats');
      if (result is Map) {
        final sample = UplinkSample.fromMap(Map<String, dynamic>.from(result), prev: _last);
        _last = sample;
        _controller.add(sample);
      }
    } catch (_) {
      // ignore errors, keep stream alive
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

final uplinkServiceProvider = Provider<UplinkService>((ref) {
  final svc = UplinkService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

final uplinkStreamProvider = StreamProvider<UplinkSample>((ref) {
  final svc = ref.watch(uplinkServiceProvider);
  svc.start();
  ref.onDispose(() => svc.stop());
  return svc.stream;
});
