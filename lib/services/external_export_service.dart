import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'encrypted_vault_service.dart';
import 'package:path_provider/path_provider.dart';
import '../services/metal_detection_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  EXTERNAL EXPORT SERVICE  V49.9
//  Real auto-export algorithm:
//  • Writes a CSV file with all matter detections to Android Downloads directory
//  • Auto-triggers on every scan complete (when exportExternal is ON)
//  • Shows a persistent notification with file path when export is done
//  • File name: falcon_eye_<timestamp>.csv
//  • CSV schema: timestamp, type, x, y, z, confidence, distanceM, elementHint
// ═══════════════════════════════════════════════════════════════════════════════

const _kChannelId = 'fe_export';
const _kChannelName = 'Falcon Eye Exports';

class ExportResult {
  final String path;
  final int rowCount;
  final DateTime exportedAt;

  const ExportResult({
    required this.path,
    required this.rowCount,
    required this.exportedAt,
  });
}

class ExternalExportState {
  final bool active;
  final ExportResult? lastExport;
  final int totalExports;
  final String status;

  const ExternalExportState({
    required this.active,
    this.lastExport,
    required this.totalExports,
    required this.status,
  });

  static ExternalExportState idle() => const ExternalExportState(
        active: false,
        totalExports: 0,
        status: 'Auto-export disabled',
      );

  ExternalExportState copyWith({
    bool? active,
    ExportResult? lastExport,
    int? totalExports,
    String? status,
  }) =>
      ExternalExportState(
        active: active ?? this.active,
        lastExport: lastExport ?? this.lastExport,
        totalExports: totalExports ?? this.totalExports,
        status: status ?? this.status,
      );
}

class ExternalExportService extends Notifier<ExternalExportState> {
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _notifInit = false;

  @override
  ExternalExportState build() {
    return ExternalExportState.idle();
  }

  void enable() => state = state.copyWith(active: true, status: 'Auto-export ON — awaiting scan');
  void disable() => state = state.copyWith(active: false, status: 'Auto-export disabled');

  /// Call this whenever a scan completes with new detections.
  Future<void> exportDetections(List<MatterDetection> detections) async {
    if (!state.active || detections.isEmpty) return;

    try {
      final dir = await _getExportDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/falcon_eye_$timestamp.csv');

      final buf = StringBuffer();
      buf.writeln('timestamp,type,x,y,z,confidence,distanceM,elementHint,susceptibility');
      final now = DateTime.now().toIso8601String();
      for (final d in detections) {
        buf.writeln(
          '$now,${d.matterType.name},'
          '${d.x.toStringAsFixed(4)},${d.y.toStringAsFixed(4)},${d.z.toStringAsFixed(4)},'
          '${d.confidence.toStringAsFixed(4)},${d.distanceMetres.toStringAsFixed(2)},'
          '${d.elementHint},${d.susceptibility.toStringAsFixed(4)}',
        );
      }
      await file.writeAsString(buf.toString());

      // Encrypted Vault: encrypt exported CSV if vault is armed
      try {
        final vault = ref.read(encryptedVaultProvider.notifier);
        if (vault.isArmed) await vault.encryptFile(file.path);
      } catch (_) {}

      final result = ExportResult(
        path: file.path,
        rowCount: detections.length,
        exportedAt: DateTime.now(),
      );
      state = state.copyWith(
        lastExport: result,
        totalExports: state.totalExports + 1,
        status: 'Exported ${detections.length} detections → ${file.path.split('/').last}',
      );
      await _notify(result);
    } catch (e) {
      state = state.copyWith(status: 'Export failed: $e');
    }
  }

  Future<Directory> _getExportDir() async {
    // Try Downloads first (Android external storage)
    try {
      final d = Directory('/storage/emulated/0/Download/FalconEye');
      await d.create(recursive: true);
      return d;
    } catch (_) {}
    // Fallback to app documents
    final doc = await getApplicationDocumentsDirectory();
    final d = Directory('${doc.path}/exports');
    await d.create(recursive: true);
    return d;
  }

  Future<void> _notify(ExportResult result) async {
    if (!_notifInit) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await (_notifications as dynamic).initialize(const InitializationSettings(android: android));
      await _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _kChannelId,
            _kChannelName,
            importance: Importance.low,
          ));
      _notifInit = true;
    }
    await (_notifications as dynamic).show(
      800,
      'Falcon Eye Export',
      '${result.rowCount} detections → ${result.path.split('/').last}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}

final externalExportProvider =
    NotifierProvider<ExternalExportService, ExternalExportState>(
  ExternalExportService.new,
);
