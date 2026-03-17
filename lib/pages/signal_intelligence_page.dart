import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/falcon_side_panel.dart';
import '../widgets/back_button_top_left.dart';
import '../services/features_provider.dart';
import '../services/hardware_capabilities_service.dart';
import '../services/cell_service.dart';
import '../services/wifi_csi_service.dart';
import '../services/uplink_service.dart';
import '../services/encrypted_vault_service.dart';
import '../services/ble_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V50.0 — SIGNAL INTELLIGENCE  (SIGINT)
//  Live cellular RSRP/SINR, CSI subcarrier stream, RF spectrogram,
//  uplink TX/RX throughput, BLE ambient scan, encrypted log export
// ═══════════════════════════════════════════════════════════════════════════════

class SignalIntelligencePage extends ConsumerStatefulWidget {
  const SignalIntelligencePage({super.key});

  @override
  ConsumerState<SignalIntelligencePage> createState() =>
      _SignalIntelligencePageState();
}

class _SignalIntelligencePageState
    extends ConsumerState<SignalIntelligencePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepCtrl;

  // Spectrogram ring buffer — 40 columns × amplitude snapshot
  final List<List<double>> _spectrogramBuf = [];
  static const _kSpecCols = 40;
  static const _kSpecRows = 32;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    // Seed spectrogram with noise
    for (int i = 0; i < _kSpecCols; i++) {
      _spectrogramBuf.add(_noiseColumn());
    }
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    super.dispose();
  }

  List<double> _noiseColumn() {
    final r = math.Random();
    return List.generate(_kSpecRows, (i) {
      // 2.4 GHz band peak at row ~10, 5 GHz peak at row ~24
      final band24 = math.exp(-math.pow((i - 10) / 4.0, 2)) * 0.6;
      final band5  = math.exp(-math.pow((i - 24) / 3.5, 2)) * 0.4;
      return (band24 + band5 + r.nextDouble() * 0.15).clamp(0.0, 1.0);
    });
  }

  void _pushCSIColumn(List<CSIDataPoint> pts) {
    if (pts.isEmpty) return;
    // Convert CSI amplitude to normalized spectrogram row
    final col = List<double>.filled(_kSpecRows, 0);
    for (final pt in pts) {
      final row = (pt.subcarrierIndex * _kSpecRows / 64).round()
          .clamp(0, _kSpecRows - 1);
      final norm = ((pt.amplitude + 90) / 60).clamp(0.0, 1.0);
      col[row] = math.max(col[row], norm);
    }
    if (mounted) {
      setState(() {
        _spectrogramBuf.add(col);
        if (_spectrogramBuf.length > _kSpecCols) _spectrogramBuf.removeAt(0);
      });
    }
  }

  // Network type integer → label
  static String _ratLabel(int v) => switch (v) {
        20 => 'NR (5G)',
        13 => 'LTE',
        15 => 'LTE+',
        8  => 'HSPA',
        3  => 'UMTS',
        2  => 'EDGE',
        1  => 'GPRS',
        _  => 'UNKNOWN',
      };

  @override
  Widget build(BuildContext context) {
    final features  = ref.watch(featuresProvider);
    final caps      = ref.watch(hardwareCapabilitiesProvider);
    final csi       = ref.watch(wifiCSIProvider);
    final bleState  = ref.watch(bleServiceProvider);
    final vault     = ref.watch(encryptedVaultProvider);
    final primary   = features.primaryColor;
    final useGlass  = features[FKey.glassmorphismHud];

    // Feed live CSI into spectrogram
    if (csi.rawData.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _pushCSIColumn(csi.rawData));
    }

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(primary, caps)),
                SliverToBoxAdapter(
                    child: _buildCellularPanel(primary, useGlass)),
                SliverToBoxAdapter(
                    child: _buildUplinkPanel(primary, useGlass)),
                SliverToBoxAdapter(
                    child: _buildCSIPanel(csi, caps, primary, useGlass)),
                SliverToBoxAdapter(
                    child: _buildSpectrogram(primary, useGlass)),
                SliverToBoxAdapter(
                    child: _buildBleAmbient(bleState, primary, useGlass)),
                SliverToBoxAdapter(
                    child: _buildFooter(vault, primary)),
                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
            ),
            const BackButtonTopLeft(),
            const FalconPanelTrigger(top: 90),
          ],
        ),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────────────────
  Widget _buildHeader(Color primary, HardwareCapabilities caps) {
    return Container(
      padding: const EdgeInsets.fromLTRB(52, 14, 16, 12),
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: primary.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('SIGNAL INTELLIGENCE',
                      style: TextStyle(
                          color: primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                  const SizedBox(width: 8),
                  _tag('V50.0', primary),
                ]),
                const SizedBox(height: 2),
                Text('SIGINT  •  CELLULAR  •  CSI  •  RF SPECTRUM',
                    style: TextStyle(
                        color: primary.withValues(alpha: 0.45),
                        fontSize: 9,
                        letterSpacing: 1)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _statusDot('LIVE', const Color(0xFF00FF66)),
            const SizedBox(height: 4),
            _tag(
              caps.tier1Flagship.enabled ? 'FLAGSHIP HW' : 'STD HW',
              caps.tier1Flagship.enabled
                  ? const Color(0xFF00CCFF)
                  : Colors.orange,
            ),
          ]),
        ],
      ),
    );
  }

  // ── CELLULAR PANEL ───────────────────────────────────────────────────────────
  Widget _buildCellularPanel(Color primary, bool glass) {
    return _glass(glass, primary,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionRow(Icons.cell_tower, 'CELLULAR LAYERS (3G / 4G / 5G)', primary),
          const SizedBox(height: 10),
          Consumer(builder: (ctx, ref, _) {
            final async = ref.watch(cellStreamProvider);
            return async.when(
              data: (cells) {
                if (cells.isEmpty) {
                  return _emptyHint('No cell data — check telephony permission', primary);
                }
                cells.sort((a, b) => b.dbm.compareTo(a.dbm));
                final serving = cells.where((c) => c.registered).toList()
                  ..sort((a, b) => b.dbm.compareTo(a.dbm));
                final top = serving.isNotEmpty ? serving.first : cells.first;
                final rsrpVal = top.rsrp?.toString() ?? top.dbm.toString();
                final sinrVal = top.rssnr?.toString() ?? '--';

                return Column(children: [
                  // Primary metrics row
                  Row(children: [
                    Expanded(child: _metricCard(
                      icon: Icons.signal_cellular_alt,
                      label: top.type == 'LTE' ? 'RSRP' : 'dBm',
                      value: rsrpVal,
                      unit: 'dBm',
                      color: _dbmColor(top.dbm),
                      glass: glass,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _metricCard(
                      icon: Icons.speed,
                      label: top.type == 'LTE' ? 'SINR' : 'ASU',
                      value: top.type == 'LTE'
                          ? sinrVal
                          : (top.asuLevel.toString()),
                      unit: top.type == 'LTE' ? 'dB' : 'level',
                      color: primary,
                      glass: glass,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _metricCard(
                      icon: Icons.network_cell,
                      label: 'TYPE',
                      value: top.type,
                      unit: top.registered ? 'SERVING' : 'NEIGHBOR',
                      color: const Color(0xFF00CCFF),
                      glass: glass,
                    )),
                  ]),
                  const SizedBox(height: 10),
                  // Nearby cells list
                  _glassBox(glass, primary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _rowLabel('NEARBY CELLS (${cells.length})', primary),
                        const SizedBox(height: 6),
                        ...cells.take(8).map((c) => _cellRow(c, primary)),
                      ],
                    ),
                  ),
                ]);
              },
              loading: () => Row(children: [
                Expanded(child: _metricCard(icon: Icons.signal_cellular_alt, label: 'RSRP', value: '--', unit: 'dBm', color: primary, glass: glass)),
                const SizedBox(width: 8),
                Expanded(child: _metricCard(icon: Icons.speed, label: 'SINR', value: '--', unit: 'dB', color: primary, glass: glass)),
              ]),
              error: (e, _) => _errorHint('Telephony error: $e', primary),
            );
          }),
        ]),
      ),
    );
  }

  Widget _cellRow(CellularCell c, Color primary) {
    final sigColor = _dbmColor(c.dbm);
    final bars = ((c.dbm + 120) / 40).clamp(0, 4).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        // Signal bars
        Row(children: List.generate(4, (i) => Container(
          width: 3, height: 6 + i * 3.0, margin: const EdgeInsets.only(right: 1),
          color: i < bars ? sigColor : sigColor.withValues(alpha: 0.15),
        ))),
        const SizedBox(width: 8),
        // Cell info
        Expanded(child: Text(
          c.type == 'LTE'
              ? 'LTE  ci:${c.ci ?? '-'}  tac:${c.tac ?? '-'}  pci:${c.pci ?? '-'}'
              : '${c.type}  cid:${c.cid ?? '-'}  lac:${c.lac ?? '-'}',
          style: TextStyle(
              color: primary.withValues(alpha: 0.75),
              fontSize: 9,
              fontFamily: 'monospace'),
          overflow: TextOverflow.ellipsis,
        )),
        const SizedBox(width: 6),
        Text('${c.dbm} dBm',
            style: TextStyle(
                color: sigColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
        const SizedBox(width: 6),
        if (c.registered)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF66).withValues(alpha: 0.12),
              border: Border.all(
                  color: const Color(0xFF00FF66).withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Text('SERVING',
                style: TextStyle(
                    color: Color(0xFF00FF66),
                    fontSize: 7,
                    fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }

  Color _dbmColor(int dbm) {
    if (dbm >= -70) return const Color(0xFF00FF66);
    if (dbm >= -90) return Colors.orange;
    return Colors.red;
  }

  // ── UPLINK MONITOR ───────────────────────────────────────────────────────────
  Widget _buildUplinkPanel(Color primary, bool glass) {
    return _glass(glass, primary,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionRow(Icons.swap_vert, 'CELLULAR UPLINK / DOWNLINK', primary),
          const SizedBox(height: 10),
          Consumer(builder: (ctx, ref, _) {
            final async = ref.watch(uplinkStreamProvider);
            return async.when(
              data: (s) => Column(children: [
                Row(children: [
                  Expanded(child: _throughputCard(
                    label: 'TX UPLINK',
                    kbps: s.uplinkKbps,
                    icon: Icons.upload,
                    color: const Color(0xFF00CCFF),
                    glass: glass,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _throughputCard(
                    label: 'RX DOWNLINK',
                    kbps: s.downlinkKbps,
                    icon: Icons.download,
                    color: primary,
                    glass: glass,
                  )),
                ]),
                const SizedBox(height: 8),
                // Throughput bar
                _glassBox(glass, primary,
                  child: Row(children: [
                    Icon(Icons.router, color: primary, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'RAT: ${_ratLabel(s.networkType)}',
                      style: TextStyle(
                          color: primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      s.isDataEnabled ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: s.isDataEnabled ? const Color(0xFF00FF66) : Colors.red,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.isDataEnabled ? 'DATA ENABLED' : 'DATA DISABLED',
                      style: TextStyle(
                          color: s.isDataEnabled
                              ? const Color(0xFF00FF66)
                              : Colors.red,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ]),
                ),
              ]),
              loading: () => Row(children: [
                Expanded(child: _throughputCard(label: 'TX UPLINK', kbps: 0, icon: Icons.upload, color: const Color(0xFF00CCFF), glass: glass)),
                const SizedBox(width: 8),
                Expanded(child: _throughputCard(label: 'RX DOWNLINK', kbps: 0, icon: Icons.download, color: primary, glass: glass)),
              ]),
              error: (e, _) => _errorHint('Uplink error: $e', primary),
            );
          }),
        ]),
      ),
    );
  }

  Widget _throughputCard({
    required String label,
    required double kbps,
    required IconData icon,
    required Color color,
    required bool glass,
  }) {
    final mbps = kbps / 1000;
    final display = mbps >= 1.0
        ? '${mbps.toStringAsFixed(1)} Mbps'
        : '${kbps.toStringAsFixed(0)} kbps';
    return _glassBox(glass, color,
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color.withValues(alpha: 0.55),
                    fontSize: 8,
                    letterSpacing: 0.5)),
            Text(display,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ],
        )),
      ]),
    );
  }

  // ── CSI STREAM PANEL ─────────────────────────────────────────────────────────
  Widget _buildCSIPanel(WiFiCSIState csi, HardwareCapabilities caps,
      Color primary, bool glass) {
    final active = caps.csiRawAccess.enabled;

    return _glass(glass, primary,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _sectionRow(Icons.wifi, 'WLAN CSI RAW STREAM', primary),
            const Spacer(),
            _tag(
              active ? 'ACTIVE' : caps.csiRawAccess.reason.toUpperCase(),
              active ? const Color(0xFF00FF66) : Colors.red,
            ),
          ]),
          const SizedBox(height: 10),
          Opacity(
            opacity: active ? 1.0 : 0.45,
            child: Column(children: [
              // Live subcarrier rows
              if (csi.rawData.isNotEmpty) ...[
                _rowLabel('LIVE SUBCARRIER DATA  —  ${csi.rawData.length} SUBCARRIERS  •  ${csi.sampleRate} Hz', primary),
                const SizedBox(height: 6),
                ...csi.rawData.take(8).map((pt) => _csiRow(pt, primary)),
              ] else ...[
                _rowLabel('CHANNEL STATE INFORMATION', primary),
                const SizedBox(height: 6),
                // Static reference rows when no live data
                _staticCSIRow('SC [00–15]', 'Φ 0.421', '−62 dBm', const Color(0xFF00CCFF)),
                _staticCSIRow('SC [16–31]', 'Φ 0.892', '−71 dBm', const Color(0xFF00CCFF)),
                _staticCSIRow('SC [32–47]', 'Φ 0.115', '−68 dBm', const Color(0xFF00CCFF)),
                _staticCSIRow('SC [48–63]', 'Φ −0.342', '−75 dBm', const Color(0xFF00CCFF)),
              ],
              if (!active) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.06),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(children: [
                    Icon(Icons.lock, color: Colors.red.shade400, size: 18),
                    const SizedBox(height: 4),
                    Text('ROOT / SHIZUKU REQUIRED FOR FULL CSI',
                        style: TextStyle(
                            color: Colors.red.shade400,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                    Text(caps.csiRawAccess.reason,
                        style: TextStyle(
                            color: Colors.red.shade400.withValues(alpha: 0.6),
                            fontSize: 8)),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _csiRow(CSIDataPoint pt, Color primary) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Container(
        width: 3, height: 18,
        color: const Color(0xFF00CCFF).withValues(
            alpha: ((pt.amplitude + 90) / 60).clamp(0.2, 1.0)),
      ),
      const SizedBox(width: 8),
      Text('SC [${pt.subcarrierIndex.toString().padLeft(2, '0')}]',
          style: TextStyle(
              color: primary.withValues(alpha: 0.5),
              fontSize: 9,
              fontFamily: 'monospace')),
      const SizedBox(width: 10),
      Expanded(child: Text(
          'Φ ${pt.phase.toStringAsFixed(3)}',
          style: const TextStyle(
              color: Color(0xFF00CCFF),
              fontSize: 9,
              fontFamily: 'monospace'))),
      Text('${pt.amplitude.toStringAsFixed(1)} dBm',
          style: TextStyle(
              color: primary, fontSize: 9, fontFamily: 'monospace')),
    ]),
  );

  Widget _staticCSIRow(String label, String phase, String amp, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Container(width: 3, height: 18, color: color.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 9,
                  fontFamily: 'monospace')),
          const Spacer(),
          Text(phase,
              style: TextStyle(
                  color: color, fontSize: 9, fontFamily: 'monospace')),
          const SizedBox(width: 16),
          Text(amp,
              style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 9,
                  fontFamily: 'monospace')),
        ]),
      );

  // ── RF SPECTROGRAM ───────────────────────────────────────────────────────────
  Widget _buildSpectrogram(Color primary, bool glass) {
    return _glass(glass, primary,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _sectionRow(Icons.graphic_eq, 'RF SPECTROGRAM', primary),
            const Spacer(),
            Text('2.4 GHz  /  5 GHz',
                style: TextStyle(
                    color: primary.withValues(alpha: 0.4),
                    fontSize: 8,
                    fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 8),
          // Frequency axis labels
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('2.400 GHz',
                style: TextStyle(color: primary.withValues(alpha: 0.4), fontSize: 7)),
            Text('3.700 GHz',
                style: TextStyle(color: primary.withValues(alpha: 0.3), fontSize: 7)),
            Text('5.800 GHz',
                style: TextStyle(color: primary.withValues(alpha: 0.4), fontSize: 7)),
          ]),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _sweepCtrl,
            builder: (_, __) => SizedBox(
              height: 120,
              child: CustomPaint(
                size: const Size(double.infinity, 120),
                painter: _SpectrogramPainter(
                  buffer: _spectrogramBuf,
                  sweepProgress: _sweepCtrl.value,
                  primaryColor: primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Legend
          Row(children: [
            _specLegend('2.4 GHz BAND', const Color(0xFF00AAFF)),
            const SizedBox(width: 16),
            _specLegend('5 GHz BAND', const Color(0xFFFF6600)),
            const Spacer(),
            Text('${_spectrogramBuf.length} frames',
                style: TextStyle(
                    color: primary.withValues(alpha: 0.3),
                    fontSize: 7,
                    fontFamily: 'monospace')),
          ]),
        ]),
      ),
    );
  }

  Widget _specLegend(String label, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.7), fontSize: 7)),
      ]);

  // ── BLE AMBIENT ──────────────────────────────────────────────────────────────
  Widget _buildBleAmbient(BleScanState ble, Color primary, bool glass) {
    if (ble.devices.isEmpty) return const SizedBox.shrink();
    return _glass(glass, primary,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionRow(Icons.bluetooth, 'BLE AMBIENT (${ble.devices.length} DEVICES)', primary),
          const SizedBox(height: 8),
          ...ble.devices.take(6).map((d) {
            final rssiNorm = ((d.rssi + 100) / 60).clamp(0.0, 1.0);
            final rssiColor = rssiNorm > 0.6
                ? const Color(0xFF00FF66)
                : rssiNorm > 0.3
                    ? Colors.orange
                    : Colors.red;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(
                  d.connectable ? Icons.bluetooth_connected : Icons.bluetooth,
                  color: rssiColor,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  d.name.isNotEmpty ? d.name : d.id,
                  style: TextStyle(
                      color: primary.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                )),
                Text('${d.rssi} dBm',
                    style: TextStyle(
                        color: rssiColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
              ]),
            );
          }).toList(),
        ]),
      ),
    );
  }

  // ── FOOTER / ACTIONS ─────────────────────────────────────────────────────────
  Widget _buildFooter(VaultState vault, Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        // Encrypt logs
        Expanded(child: GestureDetector(
          onTap: () {
            if (vault.armed) {
              ref.read(encryptedVaultProvider.notifier).disarm();
            } else {
              ref.read(encryptedVaultProvider.notifier).arm();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: vault.armed
                  ? const Color(0xFF00FF66).withValues(alpha: 0.12)
                  : primary.withValues(alpha: 0.85),
              border: Border.all(
                color: vault.armed
                    ? const Color(0xFF00FF66).withValues(alpha: 0.5)
                    : primary,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  vault.armed ? Icons.lock : Icons.lock_open,
                  color: vault.armed
                      ? const Color(0xFF00FF66)
                      : Colors.black,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  vault.armed ? 'VAULT ARMED (${vault.filesEncrypted} FILES)' : 'ARM ENCRYPTED VAULT',
                  style: TextStyle(
                    color: vault.armed ? const Color(0xFF00FF66) : Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        )),
        const SizedBox(width: 8),
        // Info icon
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: primary.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.info_outline, color: primary, size: 20),
        ),
      ]),
    );
  }

  // ── SHARED HELPERS ───────────────────────────────────────────────────────────
  Widget _glass(bool useGlass, Color primary,
      {required Widget child,
      EdgeInsets margin = const EdgeInsets.fromLTRB(12, 4, 12, 4),
      double radius = 6}) {
    if (!useGlass) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          border: Border.all(color: primary.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          margin: margin,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withValues(alpha: 0.04),
              Colors.black.withValues(alpha: 0.4),
            ]),
            border: Border.all(color: primary.withValues(alpha: 0.22)),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassBox(bool glass, Color color, {required Widget child}) =>
      Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: glass ? 0.03 : 0.05),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: child,
      );

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required bool glass,
  }) =>
      _glassBox(glass, color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.55),
                      fontSize: 7,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1)),
            Text(unit,
                style: TextStyle(
                    color: color.withValues(alpha: 0.6),
                    fontSize: 7,
                    fontWeight: FontWeight.bold)),
          ],
        ));

  Widget _sectionRow(IconData icon, String label, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      ]);

  Widget _rowLabel(String text, Color color) => Text(text,
      style: TextStyle(
          color: color.withValues(alpha: 0.5),
          fontSize: 8,
          letterSpacing: 0.8));

  Widget _tag(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 7,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4)));

  Widget _statusDot(String text, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)])),
        Text(text,
            style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8)),
      ]);

  Widget _emptyHint(String msg, Color color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(msg,
          style: TextStyle(
              color: color.withValues(alpha: 0.4), fontSize: 9)));

  Widget _errorHint(String msg, Color color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(msg,
          style:
              TextStyle(color: Colors.red.withValues(alpha: 0.7), fontSize: 9)));
}

// ═══════════════════════════════════════════════════════════════════════════════
//  RF SPECTROGRAM PAINTER  — waterfall display
// ═══════════════════════════════════════════════════════════════════════════════
class _SpectrogramPainter extends CustomPainter {
  final List<List<double>> buffer;
  final double sweepProgress;
  final Color primaryColor;

  const _SpectrogramPainter({
    required this.buffer,
    required this.sweepProgress,
    required this.primaryColor,
  });

  // Thermal colourmap: 0=black → blue → cyan → yellow → red → white
  Color _heatColor(double v) {
    if (v <= 0) return Colors.black;
    if (v < 0.25) {
      return Color.lerp(Colors.black, const Color(0xFF0033FF), v / 0.25)!;
    } else if (v < 0.5) {
      return Color.lerp(
          const Color(0xFF0033FF), const Color(0xFF00FFFF), (v - 0.25) / 0.25)!;
    } else if (v < 0.75) {
      return Color.lerp(
          const Color(0xFF00FFFF), const Color(0xFFFFFF00), (v - 0.5) / 0.25)!;
    } else {
      return Color.lerp(
          const Color(0xFFFFFF00), const Color(0xFFFF0000), (v - 0.75) / 0.25)!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (buffer.isEmpty) return;

    final cols = buffer.length;
    final rows = buffer[0].length;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        final v = buffer[c][r];
        canvas.drawRect(
          Rect.fromLTWH(c * cellW, r * cellH, cellW + 0.5, cellH + 0.5),
          Paint()..color = _heatColor(v),
        );
      }
    }

    // Sweep line
    final sx = sweepProgress * size.width;
    canvas.drawLine(
      Offset(sx, 0), Offset(sx, size.height),
      Paint()
        ..color = primaryColor.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Band divider at 2.4/5 GHz boundary (~row 16)
    final divY = size.height * 0.5;
    canvas.drawLine(
      Offset(0, divY), Offset(size.width, divY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(_SpectrogramPainter o) =>
      o.sweepProgress != sweepProgress || o.buffer != buffer;
}
