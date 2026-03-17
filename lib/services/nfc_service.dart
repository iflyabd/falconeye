import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NfcTagInfo {
  final String uidHex;
  final String tech; // e.g., Ndef, NfcA, Mifare Ultralight
  final bool ndefAvailable;
  final List<String> ndefRecords; // text preview of records

  const NfcTagInfo({
    required this.uidHex,
    required this.tech,
    required this.ndefAvailable,
    required this.ndefRecords,
  });
}

class NfcState {
  final bool supported;
  final bool enabled; // user setting / hardware enabled
  final bool scanning;
  final String statusMessage;
  final NfcTagInfo? lastTag;

  const NfcState({
    required this.supported,
    required this.enabled,
    required this.scanning,
    required this.statusMessage,
    required this.lastTag,
  });

  NfcState copyWith({
    bool? supported,
    bool? enabled,
    bool? scanning,
    String? statusMessage,
    NfcTagInfo? lastTag,
  }) => NfcState(
        supported: supported ?? this.supported,
        enabled: enabled ?? this.enabled,
        scanning: scanning ?? this.scanning,
        statusMessage: statusMessage ?? this.statusMessage,
        lastTag: lastTag ?? this.lastTag,
      );

  factory NfcState.initial() => const NfcState(
        supported: false,
        enabled: false,
        scanning: false,
        statusMessage: 'Idle',
        lastTag: null,
      );
}

class NfcService extends Notifier<NfcState> {
  StreamSubscription? _events;

  @override
  NfcState build() {
    // probe availability lazily
    _probe();
    return NfcState.initial();
  }

  Future<void> _probe() async {
    try {
      final isAvailable = await NfcManager.instance.isAvailable();
      state = state.copyWith(supported: true, enabled: isAvailable);
    } catch (e) {
      state = state.copyWith(supported: false, enabled: false, statusMessage: 'NFC check failed: $e');
    }
  }

  Future<void> startScanning() async {
    if (state.scanning) return;
    await _probe();
    if (!state.supported) {
      state = state.copyWith(statusMessage: 'NFC not supported on this device');
      return;
    }
    if (!state.enabled) {
      state = state.copyWith(statusMessage: 'NFC is disabled. Enable it in system settings.');
      return;
    }

    state = state.copyWith(scanning: true, statusMessage: 'Hold a key card/fob to the phone');

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (tag) async {
          final info = _parseTag(tag);
          state = state.copyWith(lastTag: info, statusMessage: 'Tag discovered: ${info.tech}');
          // For single-shot read, end session automatically
          try { await NfcManager.instance.stopSession(); } catch (_) {}
          state = state.copyWith(scanning: false);
        },
      );
    } catch (e) {
      state = state.copyWith(statusMessage: 'Failed to start NFC: $e', scanning: false);
    }
  }

  Future<void> stopScanning() async {
    if (!state.scanning) return;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
    state = state.copyWith(scanning: false, statusMessage: 'Scan stopped');
  }

  NfcTagInfo _parseTag(NfcTag tag) {
    // Best-effort parse
    String uid = 'unknown';
    try {
      final data = tag.data as Map; // platform map
      // Common locations for ID on Android (nfca / nfcv / isoDep)
      Uint8List? idBytes;
      for (final key in ['mifare', 'nfca', 'nfcv', 'iso7816', 'felica']) {
        if (data.containsKey(key) && data[key] is Map) {
          final m = data[key] as Map;
          if (m.containsKey('identifier') && m['identifier'] is Uint8List) {
            idBytes = m['identifier'] as Uint8List;
            break;
          }
          if (m.containsKey('id') && m['id'] is Uint8List) {
            idBytes = m['id'] as Uint8List;
            break;
          }
        }
      }
      // iOS puts it top-level sometimes
      if (idBytes == null && data['id'] is Uint8List) {
        idBytes = data['id'] as Uint8List;
      }
      if (idBytes != null) {
        uid = _toHex(idBytes);
      }
    } catch (_) {}

    // Detect tech and NDEF
    String tech = 'Unknown';
    bool ndefAvailable = false;
    final records = <String>[];

    try {
      final data = tag.data as Map; // platform map
      if (data.containsKey('ndef')) {
        ndefAvailable = true;
        tech = 'NDEF';
      } else if (data.containsKey('nfca')) {
        tech = 'NfcA (ISO14443-3A)';
      } else if (data.containsKey('mifare')) {
        tech = 'MIFARE';
      } else if (data.containsKey('iso7816')) {
        tech = 'ISO-DEP (ISO14443-4)';
      } else if (data.containsKey('nfcf')) {
        tech = 'NfcF (Felica)';
      } else if (data.containsKey('nfcv')) {
        tech = 'NfcV (ISO15693)';
      }
    } catch (e) {
      if (kDebugMode) {
        print('NDEF parse error: $e');
      }
    }

    return NfcTagInfo(
      uidHex: uid,
      tech: tech,
      ndefAvailable: ndefAvailable,
      ndefRecords: records,
    );
  }

  String _toHex(Uint8List bytes) {
    final StringBuffer sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
      sb.write(':');
    }
    final s = sb.toString();
    return s.isEmpty ? '' : s.substring(0, s.length - 1).toUpperCase();
  }

}

final nfcProvider = NotifierProvider<NfcService, NfcState>(() => NfcService());
