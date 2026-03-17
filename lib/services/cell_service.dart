import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class CellularCell {
  final String type; // LTE or WCDMA
  final bool registered;
  final int mcc;
  final int mnc;
  final int? ci; // LTE cell id
  final int? tac; // LTE tracking area code
  final int? pci; // LTE physical cell id
  final int? earfcn; // LTE frequency number
  final int? rsrp; // LTE
  final int? rsrq; // LTE
  final int? rssnr; // LTE
  final int? lac; // WCDMA
  final int? cid; // WCDMA
  final int? psc; // WCDMA
  final int? uarfcn; // WCDMA frequency
  final int asuLevel;
  final int dbm;

  CellularCell({
    required this.type,
    required this.registered,
    required this.mcc,
    required this.mnc,
    this.ci,
    this.tac,
    this.pci,
    this.earfcn,
    this.rsrp,
    this.rsrq,
    this.rssnr,
    this.lac,
    this.cid,
    this.psc,
    this.uarfcn,
    required this.asuLevel,
    required this.dbm,
  });

  factory CellularCell.fromMap(Map data) {
    return CellularCell(
      type: data['type'] ?? 'UNKNOWN',
      registered: data['registered'] == true,
      mcc: (data['mcc'] ?? -1) as int,
      mnc: (data['mnc'] ?? -1) as int,
      ci: data['ci'] as int?,
      tac: data['tac'] as int?,
      pci: data['pci'] as int?,
      earfcn: data['earfcn'] as int?,
      rsrp: data['rsrp'] as int?,
      rsrq: data['rsrq'] as int?,
      rssnr: data['rssnr'] as int?,
      lac: data['lac'] as int?,
      cid: data['cid'] as int?,
      psc: data['psc'] as int?,
      uarfcn: data['uarfcn'] as int?,
      asuLevel: (data['asuLevel'] ?? 0) as int,
      dbm: (data['dbm'] ?? -150) as int,
    );
  }
}

class CellService {
  static const _channel = MethodChannel('falcon_eye/cell');
  final _controller = StreamController<List<CellularCell>>.broadcast();
  Timer? _timer;

  Stream<List<CellularCell>> get cellsStream => _controller.stream;

  Future<void> start({Duration interval = const Duration(seconds: 5)}) async {
    // Ensure we have location permission for cell info
    final status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
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
      final result = await _channel.invokeMethod('getCellInfo');
      if (result is List) {
        final parsed = result.map((e) => CellularCell.fromMap(Map<String, dynamic>.from(e))).toList();
        _controller.add(parsed);
      }
    } catch (e) {
      // swallow errors and keep stream alive
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

final cellServiceProvider = Provider<CellService>((ref) {
  final svc = CellService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

final cellStreamProvider = StreamProvider<List<CellularCell>>((ref) {
  final svc = ref.watch(cellServiceProvider);
  // start polling when first listened
  svc.start();
  ref.onDispose(() => svc.stop());
  return svc.cellsStream;
});
