// =============================================================================
// FALCON EYE V50.0 — SETTINGS & HARDWARE PAGE
// Upgrades vs V47.7:
//   • Version badge → V50.0; footer → V50.0
//   • Sovereignty protocol toggles wired to featuresProvider (no more const)
//   • Bar chart driven by real capability booleans (not hardcoded array)
//   • CSI sample rate buttons wired (tap sets bio FFT via available API)
//   • NEW: Full FKey feature-toggle panel grouped by FKey.sections
//   • Theme color from featuresProvider.primaryColor throughout
//   • MetallurgicRadarState.scanDepth converted correctly (×100 for cm slider)
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../widgets/falcon_side_panel.dart';
import '../services/hardware_capabilities_service.dart';
import '../services/gyroscopic_camera_service.dart';
import '../services/background_recording_service.dart';
import '../services/security_camera_service.dart';
import '../services/bio_tomography_service.dart';
import '../services/metallurgic_radar_service.dart';
import '../services/features_provider.dart';
import '../services/stealth_service.dart';
import '../services/gamepad_settings_provider.dart';
import '../widgets/back_button_top_left.dart';

// ── Icon helper ───────────────────────────────────────────────────────────────
IconData _iconForCap(String name) {
  final n = name.toLowerCase();
  if (n.contains('2g') || n.contains('gsm'))       return Icons.grid_3x3;
  if (n.contains('3g') || n.contains('umts'))       return Icons.network_cell;
  if (n.contains('4g') || n.contains('lte'))        return Icons.signal_cellular_alt;
  if (n.contains('5g') || n.contains('nr'))         return Icons.cell_tower;
  if (n.contains('wi-fi') || n.contains('wifi'))    return Icons.wifi;
  if (n.contains('monitor'))                         return Icons.radar;
  if (n.contains('csi'))                             return Icons.graphic_eq;
  if (n.contains('ble') || n.contains('bt ') || n.contains('bluetooth')) return Icons.bluetooth_connected;
  if (n.contains('nfc'))                             return Icons.nfc;
  if (n.contains('uwb'))                             return Icons.radar;
  if (n.contains('accel'))                           return Icons.phone_android;
  if (n.contains('gyro'))                            return Icons.rotate_90_degrees_ccw;
  if (n.contains('magnet'))                          return Icons.explore;
  if (n.contains('gravity') || n.contains('linear') || n.contains('rotation')) return Icons.threed_rotation;
  if (n.contains('step'))                            return Icons.directions_walk;
  if (n.contains('baro') || n.contains('pressure')) return Icons.compress;
  if (n.contains('thermo') || n.contains('temp'))   return Icons.thermostat;
  if (n.contains('hygro') || n.contains('humid'))   return Icons.water_drop;
  if (n.contains('light'))                           return Icons.light_mode;
  if (n.contains('proxim'))                          return Icons.sensors;
  if (n.contains('root'))                            return Icons.verified_user;
  if (n.contains('sdr') || n.contains('usb'))       return Icons.usb;
  if (n.contains('biometric'))                       return Icons.fingerprint;
  if (n.contains('tier') || n.contains('flagship')) return Icons.star;
  return Icons.memory;
}

// =============================================================================
class SettingsHardwarePage extends ConsumerWidget {
  const SettingsHardwarePage({super.key});

  // ── Gain controls ─────────────────────────────────────────────────────────
  Widget _buildGainControls(BuildContext ctx, WidgetRef ref, Color color) {
    final bio      = ref.watch(bioTomographyProvider);
    final metRadar = ref.watch(metallurgicRadarProvider);
    return Column(children: [
      _SliderCard(
        title: 'BIO-TOMOGRAPHY GAIN',
        subtitle: 'Signal amplification for FFT bio-frequency extraction',
        value: bio.sensitivityGain,
        min: 0.1, max: 5.0, divisions: 49,
        label: '${bio.sensitivityGain.toStringAsFixed(1)}x',
        color: color,
        onChanged: (v) => ref.read(bioTomographyProvider.notifier).setSensitivity(v),
      ),
      _SliderCard(
        title: 'METALLURGIC SCAN DEPTH',
        subtitle: 'Max depth for subsurface element detection',
        value: metRadar.scanDepthCm,
        min: 10, max: 500, divisions: 49,
        label: '${metRadar.scanDepthCm.toStringAsFixed(0)} cm',
        color: color,
        onChanged: (v) => ref.read(metallurgicRadarProvider.notifier).setScanDepth(v / 100),
      ),
    ]);
  }

  // ── FFT controls ─────────────────────────────────────────────────────────
  Widget _buildFFTControls(BuildContext ctx, WidgetRef ref, Color color) {
    final bio = ref.watch(bioTomographyProvider);
    // CSI rate buttons snap via setFFTWindowSize as approximate proxy
    const rates = [10.0, 20.0, 50.0, 100.0];
    final windowMap = {10.0: 64, 20.0: 128, 50.0: 256, 100.0: 512};
    return Column(children: [
      _SliderCard(
        title: 'FFT WINDOW SIZE',
        subtitle: 'Samples per FFT cycle — larger = more precise, slower',
        value: bio.fftWindowSize.toDouble(),
        min: 64, max: 1024, divisions: 15,
        label: '${bio.fftWindowSize}',
        color: color,
        onChanged: (v) => ref.read(bioTomographyProvider.notifier).setFFTWindowSize(v.round()),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.2)),
          color: color.withValues(alpha: 0.02),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('CSI SAMPLE RATE',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Target Hz for CSI collection (${bio.csiSampleRate.toStringAsFixed(0)} Hz current)',
              style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 10)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rates.map((rate) {
              final active = (bio.csiSampleRate - rate).abs() < 5;
              return GestureDetector(
                onTap: () => ref.read(bioTomographyProvider.notifier)
                    .setFFTWindowSize(windowMap[rate] ?? 256),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: active ? 0.2 : 0.05),
                    border: Border.all(color: color.withValues(alpha: active ? 0.8 : 0.25)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${rate.toStringAsFixed(0)}Hz',
                      style: TextStyle(color: color, fontSize: 11,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
      // Bio status
      Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: bio.isActive
              ? const Color(0xFF00FF41) : color.withValues(alpha: 0.2)),
          color: bio.isActive
              ? const Color(0xFF00FF41).withValues(alpha: 0.04) : Colors.transparent,
        ),
        child: Row(children: [
          Icon(bio.isActive ? Icons.graphic_eq : Icons.pause,
              color: bio.isActive ? const Color(0xFF00FF41) : color.withValues(alpha: 0.4),
              size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Bio-Tomography: ${bio.status}  ·  Entities: ${bio.entities.length}'
            '  ·  HR bands: ${bio.heartRateBands.length}',
            style: TextStyle(
                color: bio.isActive ? const Color(0xFF00FF41) : color.withValues(alpha: 0.4),
                fontSize: 10, fontFamily: 'monospace'),
          )),
        ]),
      ),
    ]);
  }

  // ── Theme / UTI ──────────────────────────────────────────────────────────
  Widget _buildUTIControls(BuildContext ctx, WidgetRef ref, Color color) {
    final features = ref.watch(featuresProvider);
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.2)),
        color: color.withValues(alpha: 0.02),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('TACTICAL THEME',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text('Instantly updates all UI, renderers, and overlays.',
            style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 10)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8,
          children: FalconTheme.values.map((t) {
            final active = features.theme == t;
            final tc = t.primary;
            return GestureDetector(
              onTap: () => ref.read(featuresProvider.notifier).setThemeProfile(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tc.withValues(alpha: active ? 0.25 : 0.06),
                  border: Border.all(color: active ? tc : tc.withValues(alpha: 0.3),
                      width: active ? 2 : 1),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: active
                      ? [BoxShadow(color: tc.withValues(alpha: 0.4), blurRadius: 8)]
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.icon, color: tc, size: 12),
                  const SizedBox(width: 5),
                  Text(t.label,
                      style: TextStyle(color: tc, fontSize: 9,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          letterSpacing: 0.5)),
                ]),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ── FKey feature toggles ─────────────────────────────────────────────────
  Widget _buildFeatureToggles(BuildContext ctx, WidgetRef ref, Color color) {
    final features = ref.watch(featuresProvider);
    final hasRoot  = ref.watch(featuresProvider).hasRoot;

    return Column(children: [
      for (final section in FKey.sections) ...[
        _SectionHeader(section.title, section.color),
        const SizedBox(height: 6),
        for (final key in section.keys) Builder(builder: (ctx) {
          final meta    = featureMeta(key);
          final enabled = features[key];
          final locked  = meta.requiresRoot && !hasRoot;
          return _FeatureToggleRow(
            icon:    meta.icon,
            label:   meta.label,
            desc:    meta.description,
            value:   enabled,
            locked:  locked,
            color:   color,
            onChanged: locked ? null
                : (v) => ref.read(featuresProvider.notifier).toggle(key, value: v),
          );
        }),
        const SizedBox(height: 12),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color       = ref.watch(featuresProvider).primaryColor;
    final caps        = ref.watch(hardwareCapabilitiesProvider);
    final gyroCamera  = ref.watch(gyroscopicCameraProvider);
    final gyroSvc     = ref.read(gyroscopicCameraProvider.notifier);
    final bgRec       = ref.watch(backgroundRecordingProvider);
    final bgRecSvc    = ref.read(backgroundRecordingProvider.notifier);
    final secCam      = ref.watch(securityCameraProvider);
    final secCamSvc   = ref.read(securityCameraProvider.notifier);

    // Bar chart data from real capabilities
    final chartData = [
      ('5G',   caps.cellular5G.enabled   ? 95.0 : 5.0),
      ('4G',   caps.cellular4G.enabled   ? 82.0 : 5.0),
      ('3G',   caps.cellular3G.enabled   ? 55.0 : 5.0),
      ('2G',   caps.cellular2G.enabled   ? 40.0 : 5.0),
      ('WiFi', caps.wifi7.enabled        ? 90.0 : caps.wifi6.enabled ? 70.0 : 45.0),
      ('BT',   caps.ble5.enabled         ? 75.0 : caps.ble4.enabled  ? 55.0 : 5.0),
      ('UWB',  caps.uwbChipset.enabled   ? 60.0 : 5.0),
    ];

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ── Header ──────────────────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SYSTEM_CFG',
                      style: TextStyle(color: color, fontSize: 9,
                          letterSpacing: 2, fontFamily: 'monospace')),
                  Text('HARDWARE ARCHIVE',
                      style: TextStyle(color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 1.5),
                    color: color.withValues(alpha: 0.08),
                  ),
                  child: Text('V50.0', style: TextStyle(color: color,
                      fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Rescan button ────────────────────────────────────────────
              GestureDetector(
                onTap: () => ref.read(hardwareCapabilitiesProvider.notifier).scanHardware(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12)],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.refresh, color: Colors.black, size: 22),
                    const SizedBox(width: 12),
                    const Text('RESCAN FULL RF STACK',
                        style: TextStyle(color: Colors.black, fontSize: 14,
                            fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              // ── Active spectrum chips ────────────────────────────────────
              _SectionHeader('ACTIVE_SPECTRUM_CHIPS', color),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _WaveChip(Icons.cell_tower,          '5G_NR',    'Sub-6/mmW',   caps.cellular5G.enabled,    color),
                _WaveChip(Icons.signal_cellular_alt, '4G_LTE',   '700M–3.5GHz', caps.cellular4G.enabled,    color),
                _WaveChip(Icons.network_cell,        '3G_HSPA',  '900/2100MHz', caps.cellular3G.enabled,    color),
                _WaveChip(Icons.grid_3x3,            '2G_EDGE',  '850/1900MHz', caps.cellular2G.enabled,    color),
                _WaveChip(Icons.wifi,                'WiFi_7_BE','2.4/5/6GHz',  caps.wifi7.enabled,         color),
                _WaveChip(Icons.wifi,                'WiFi_6E',  '6 GHz',       caps.wifi6e.enabled,        color),
                _WaveChip(Icons.wifi,                'WiFi_6',   '2.4/5GHz',    caps.wifi6.enabled,         color),
                _WaveChip(Icons.wifi,                'WiFi_5',   '5 GHz',       caps.wifi5.enabled,         color),
                _WaveChip(Icons.bluetooth_connected, 'BT_5.x',   '2.4GHz',      caps.ble5.enabled,          color),
                _WaveChip(Icons.bluetooth,           'BLE_4.x',  '2.4GHz',      caps.ble4.enabled,          color),
                _WaveChip(Icons.radar,               'UWB_Z',    '6.5–9GHz',    caps.uwbChipset.enabled,    color),
                _WaveChip(Icons.nfc,                 'NFC_HF',   '13.56MHz',    caps.nfc.enabled,           color),
                _WaveChip(Icons.graphic_eq,          'CSI_RAW',  '2.4/5GHz',    caps.csiRawAccess.enabled,  color),
                _WaveChip(Icons.explore,             'MAGNET',   'DC field',     caps.magnetometer.enabled,  color),
                _WaveChip(Icons.compress,            'BARO',     'hPa',          caps.barometer.enabled,     color),
              ]),
              const SizedBox(height: 20),

              // ── Spectrum density bar chart ──────────────────────────────
              _SectionHeader('FULL_SPECTRUM_DENSITY', color),
              const SizedBox(height: 8),
              Container(
                height: 200,
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                  color: color.withValues(alpha: 0.02),
                ),
                child: BarChart(BarChartData(
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        return i < chartData.length
                            ? Padding(padding: const EdgeInsets.only(top: 6),
                                child: Text(chartData[i].$1,
                                    style: TextStyle(color: color.withValues(alpha: 0.5),
                                        fontSize: 9)))
                            : const SizedBox();
                      },
                    )),
                    leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true, drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                        color: color.withValues(alpha: 0.07), strokeWidth: 1),
                  ),
                  barGroups: chartData.asMap().entries.map((e) => BarChartGroupData(
                    x: e.key,
                    barRods: [BarChartRodData(
                      toY: e.value.$2,
                      color: e.value.$2 > 20 ? color : color.withValues(alpha: 0.25),
                      width: 20,
                      borderRadius: BorderRadius.circular(2),
                    )],
                  )).toList(),
                )),
              ),
              const SizedBox(height: 20),

              // ── Live hardware archive ──────────────────────────────────
              _SectionHeader('LIVE_HARDWARE_ARCHIVE', color),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                  color: color.withValues(alpha: 0.04),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(caps.deviceModel,
                      style: TextStyle(color: color, fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Android ${caps.androidVersion} (SDK ${caps.sdkInt})'
                      ' · ${caps.chipset} · ${caps.cpuAbi}',
                      style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 9,
                          fontFamily: 'monospace')),
                ]),
              ),
              for (final section in caps.sections) ...[
                Padding(padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(children: [
                    Container(width: 2, height: 10,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(1))),
                    const SizedBox(width: 6),
                    Text(section.section,
                        style: TextStyle(color: color, fontSize: 9, letterSpacing: 2)),
                  ]),
                ),
                for (final item in section.items)
                  _CapabilityTile(
                    icon:    _iconForCap(item.$1),
                    name:    item.$1,
                    status:  item.$2.detail != null && item.$2.detail!.isNotEmpty
                        ? '${item.$2.reason} · ${item.$2.detail}'
                        : item.$2.reason,
                    enabled: item.$2.enabled,
                    color:   color,
                  ),
              ],
              const SizedBox(height: 20),

              // ── Sovereignty protocols (wired) ──────────────────────────
              _SectionHeader('SOVEREIGNTY_PROTOCOLS', color),
              const SizedBox(height: 6),
              _buildSovereigntyToggles(context, ref, color),
              const SizedBox(height: 20),

              // ── Gyroscopic motion control ──────────────────────────────
              _SectionHeader('GYROSCOPIC_MOTION_CONTROL', color),
              const SizedBox(height: 6),
              _ToggleRow('DEVICE_MOTION_TRACKING',
                  'Tilt phone to look around 3D vision modes.',
                  gyroCamera.isEnabled, color,
                  (v) => gyroSvc.setEnabled(v)),
              if (gyroCamera.isEnabled) ...[
                _ToggleRow('INCLUDE_ROLL',
                    'Track tilt/rotation around forward axis.',
                    gyroCamera.includeRoll, color,
                    (v) => gyroSvc.setIncludeRoll(v)),
                _ToggleRow('TOUCH_FALLBACK',
                    'Allow swipe gestures when gyro disabled.',
                    gyroCamera.touchControlEnabled, color,
                    (v) => gyroSvc.setTouchControlEnabled(v)),
                _SliderCard(
                  title: 'SENSITIVITY',
                  subtitle: 'How responsive to phone movement',
                  value: gyroCamera.sensitivity,
                  min: 0.1, max: 2.0, divisions: 19,
                  label: '${gyroCamera.sensitivity.toStringAsFixed(1)}x',
                  color: color,
                  onChanged: (v) => gyroSvc.setSensitivity(v),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                    color: color.withValues(alpha: 0.03),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('CALIBRATION',
                          style: TextStyle(color: color, fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(gyroCamera.isCalibrated
                              ? 'Calibrated — current orientation is zero.'
                              : 'Set current phone orientation as centre.',
                          style: TextStyle(
                              color: gyroCamera.isCalibrated
                                  ? const Color(0xFF00FF41)
                                  : color.withValues(alpha: 0.5),
                              fontSize: 10)),
                    ])),
                    GestureDetector(
                      onTap: gyroCamera.isCalibrated
                          ? () => gyroSvc.resetCalibration()
                          : () => gyroSvc.calibrate(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(gyroCamera.isCalibrated ? 'RESET' : 'CALIBRATE',
                            style: const TextStyle(color: Colors.black, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: color.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    'YAW=${(gyroCamera.camera.yaw * 180 / 3.14159).toStringAsFixed(1)}°'
                    '  PITCH=${(gyroCamera.camera.pitch * 180 / 3.14159).toStringAsFixed(1)}°'
                    '  ROLL=${(gyroCamera.camera.roll * 180 / 3.14159).toStringAsFixed(1)}°',
                    style: TextStyle(color: color.withValues(alpha: 0.5),
                        fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ── 3D Gamepad Controls ─────────────────────────────────────
              _SectionHeader('3D_GAMEPAD_CONTROLS', color),
              const SizedBox(height: 8),
              _GamepadSettingsSection(color: color),
              const SizedBox(height: 20),

              // ── Background recording ───────────────────────────────────
              _SectionHeader('BACKGROUND_RECORDING', color),
              const SizedBox(height: 6),
              _ToggleRow('CONTINUOUS_RECORDING',
                  'Record signal data periodically even when screen off.',
                  bgRec.config.isEnabled, color,
                  (v) => bgRecSvc.setEnabled(v)),
              if (bgRec.config.isEnabled) ...[
                _ToggleRow('LOW_BATTERY_MODE',
                    'Reduce frequency when battery is low.',
                    bgRec.config.lowBatteryMode, color,
                    (v) => bgRecSvc.setLowBatteryMode(v)),
                _SliderCard(
                  title: 'RECORDING_INTERVAL',
                  subtitle: 'Record every N minutes',
                  value: bgRec.config.recordingIntervalMinutes.toDouble(),
                  min: 15, max: 180, divisions: 11,
                  label: '${bgRec.config.recordingIntervalMinutes}min',
                  color: color,
                  onChanged: (v) => bgRecSvc.setRecordingInterval(v.toInt()),
                ),
                _SliderCard(
                  title: 'RECORDING_DURATION',
                  subtitle: 'Minutes of signal data per session',
                  value: bgRec.config.durationMinutes.toDouble(),
                  min: 1, max: 30, divisions: 29,
                  label: '${bgRec.config.durationMinutes}min',
                  color: color,
                  onChanged: (v) => bgRecSvc.setRecordingDuration(v.toInt()),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.15))),
                  child: Text(
                    'Total: ${bgRec.totalRecordings} recordings  ·  '
                    'Last: ${bgRec.lastRecordingTime != null ? bgRec.lastRecordingTime!.toIso8601String().split('T')[1].substring(0, 5) : 'Never'}',
                    style: TextStyle(color: color.withValues(alpha: 0.5),
                        fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ── Radio security camera ──────────────────────────────────
              _SectionHeader('RADIO_SECURITY_CAMERA', color),
              const SizedBox(height: 6),
              _ToggleRow('SECURITY_MODE',
                  'Invisible home security using only radio waves.',
                  secCam.config.isEnabled, color,
                  (v) => secCamSvc.setEnabled(v)),
              if (secCam.config.isEnabled) ...[
                _ToggleRow('MOTION_DETECTION', 'Detect movement via CSI variance.',
                    secCam.config.motionDetection, color,
                    (v) => secCamSvc.setMotionDetection(v)),
                _ToggleRow('HUMAN_DETECTION', 'Doppler shift human presence.',
                    secCam.config.humanDetection, color,
                    (v) => secCamSvc.setHumanDetection(v)),
                _ToggleRow('ANOMALY_DETECTION', '3D reconstruction diff alert.',
                    secCam.config.anomalyDetection, color,
                    (v) => secCamSvc.setAnomalyDetection(v)),
                _ToggleRow('RECORD_ON_EVENT', 'Auto-record 30s clip on event.',
                    secCam.config.recordOnEvent, color,
                    (v) => secCamSvc.setRecordOnEvent(v)),
                _ToggleRow('NOTIFY_ON_EVENT', 'Push notification on event.',
                    secCam.config.notifyOnEvent, color,
                    (v) => secCamSvc.setNotifyOnEvent(v)),
                if (secCam.config.notifyOnEvent)
                  _ToggleRow('SILENT_NOTIFICATIONS', 'No sound or vibration.',
                      secCam.config.silentNotifications, color,
                      (v) => secCamSvc.setSilentNotifications(v)),
                _SliderCard(
                  title: 'DETECTION_SENSITIVITY',
                  subtitle: 'Detection threshold percentage',
                  value: secCam.config.sensitivity,
                  min: 0.1, max: 1.0, divisions: 9,
                  label: '${(secCam.config.sensitivity * 100).toStringAsFixed(0)}%',
                  color: color,
                  onChanged: (v) => secCamSvc.setSensitivity(v),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: secCam.isMonitoring
                        ? const Color(0xFF00FF41) : const Color(0xFFFF3333).withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    Icon(secCam.isMonitoring ? Icons.visibility : Icons.visibility_off,
                        color: secCam.isMonitoring
                            ? const Color(0xFF00FF41) : const Color(0xFFFF3333),
                        size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      secCam.isMonitoring
                          ? 'Monitoring active  ·  ${secCam.totalEvents} events'
                              '  ·  Last: ${secCam.lastEventTime?.toIso8601String().split('T')[1].substring(0, 5) ?? 'None'}'
                          : 'Monitoring inactive',
                      style: TextStyle(
                          color: secCam.isMonitoring
                              ? const Color(0xFF00FF41) : const Color(0xFFFF3333),
                          fontSize: 10, fontFamily: 'monospace'),
                    )),
                  ]),
                ),
                if (secCam.events.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                        border: Border.all(color: color.withValues(alpha: 0.3))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('RECENT_EVENTS',
                            style: TextStyle(color: color, fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () => secCamSvc.clearAllEvents(),
                          child: Text('CLEAR',
                              style: TextStyle(color: const Color(0xFFFF3333),
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ...secCam.events.reversed.take(5).map((event) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${event.timestamp.toIso8601String().split('T')[1].substring(0, 8)}'
                          '  ·  ${event.type.name.toUpperCase()}'
                          '  (${(event.confidence * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(color: color.withValues(alpha: 0.5),
                              fontSize: 9, fontFamily: 'monospace'),
                        ),
                      )),
                    ]),
                  ),
              ],
              const SizedBox(height: 20),

              // ── Root signal gain ───────────────────────────────────────
              _SectionHeader('ROOT_SIGNAL_GAIN_CONTROLS', color),
              const SizedBox(height: 6),
              _buildGainControls(context, ref, color),
              const SizedBox(height: 20),

              // ── FFT engine ────────────────────────────────────────────
              _SectionHeader('FFT_SENSITIVITY_ENGINE', color),
              const SizedBox(height: 6),
              _buildFFTControls(context, ref, color),
              const SizedBox(height: 20),

              // ── UTI theme ─────────────────────────────────────────────
              _SectionHeader('UNIFIED_TACTICAL_INTERFACE', color),
              const SizedBox(height: 6),
              _buildUTIControls(context, ref, color),
              const SizedBox(height: 20),

              // ── Full FKey feature toggles (NEW V50.0) ─────────────────
              _SectionHeader('FEATURE_TOGGLE_MATRIX', color),
              const SizedBox(height: 6),
              _buildFeatureToggles(context, ref, color),
              const SizedBox(height: 20),

              // ── Data vault metrics ────────────────────────────────────
              _SectionHeader('DATA_VAULT_METRICS', color),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                  color: color.withValues(alpha: 0.02),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('ENCRYPTED_SIGNAL_LOGS',
                        style: TextStyle(color: color.withValues(alpha: 0.6),
                            fontSize: 10, letterSpacing: 1)),
                    Text('84.2 GB FREE',
                        style: TextStyle(color: color, fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: 0.65,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.1),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF3333),
                          side: const BorderSide(color: Color(0xFFFF3333)),
                          minimumSize: const Size(0, 32)),
                      child: const Text('PURGE_LOGS', style: TextStyle(fontSize: 11)),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 32)),
                      child: const Text('EXPORT_PARQUET',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ]),
              ),

              // ── Footer ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Column(children: [
                  Text('FALCON_EYE_OS V50.0  //  KERNEL: 5.10.43-GEN-2',
                      style: TextStyle(color: color.withValues(alpha: 0.25),
                          fontSize: 9, fontFamily: 'monospace')),
                  const SizedBox(height: 2),
                  Text('Sovereign Android  —  OpenGL ES 2.0  +  Bio-Tomography',
                      style: TextStyle(color: color.withValues(alpha: 0.2),
                          fontSize: 9, fontFamily: 'monospace')),
                ])),
              ),
            ]),
          ),
          const BackButtonTopLeft(),
          const FalconPanelTrigger(top: 90),
        ]),
      ),
    );
  }

  Widget _buildSovereigntyToggles(BuildContext ctx, WidgetRef ref, Color color) {
    final features = ref.watch(featuresProvider);
    final stealth  = ref.watch(stealthProtocolProvider);

    return Column(children: [
      _ToggleRow('STEALTH_MODE', 'Zero RF emission, passive harvesting only.',
          stealth, color,
          (_) => ref.read(stealthProtocolProvider.notifier).toggle()),
      _ToggleRow('OFFLINE_FIRST', 'Disable all cloud-sync & external telemetry.',
          features[FKey.stealthMode], color,
          (v) => ref.read(featuresProvider.notifier).toggle(FKey.stealthMode, value: v)),
      _ToggleRow('WIFI_SNOOPING', 'Capture raw beacon frames for positioning.',
          features[FKey.wifiCSI], color,
          (v) => ref.read(featuresProvider.notifier).toggle(FKey.wifiCSI, value: v)),
      _ToggleRow('BLE_SCAN', 'Continuous BLE device discovery.',
          features[FKey.bluetoothScan], color,
          (v) => ref.read(featuresProvider.notifier).toggle(FKey.bluetoothScan, value: v)),
    ]);
  }
}

// =============================================================================
// SUBWIDGETS
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader(this.title, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 16,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)])),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(color: color, fontSize: 11,
        fontWeight: FontWeight.bold, letterSpacing: 2)),
  ]);
}

class _WaveChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String freq;
  final bool enabled;
  final Color color;
  const _WaveChip(this.icon, this.label, this.freq, this.enabled, this.color);
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1.0 : 0.35,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: enabled ? color.withValues(alpha: 0.08) : Colors.transparent,
        border: Border.all(color: enabled ? color.withValues(alpha: 0.5) : const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: enabled ? color : const Color(0xFF444444), size: 14),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: enabled ? color : const Color(0xFF444444),
              fontSize: 9, fontWeight: FontWeight.bold)),
          Text(freq, style: TextStyle(color: enabled ? color.withValues(alpha: 0.5)
              : const Color(0xFF333333), fontSize: 8)),
        ]),
      ]),
    ),
  );
}

class _CapabilityTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String status;
  final bool enabled;
  final Color color;
  const _CapabilityTile({required this.icon, required this.name,
      required this.status, required this.enabled, required this.color});
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1.0 : 0.45,
    child: Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: enabled ? color.withValues(alpha: 0.3) : const Color(0xFF222222)),
        color: enabled ? color.withValues(alpha: 0.03) : Colors.transparent,
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: enabled ? color.withValues(alpha: 0.12) : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, color: enabled ? color : const Color(0xFF444444), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(
              color: enabled ? Colors.white : const Color(0xFF555555),
              fontSize: 12, fontWeight: FontWeight.w600)),
          Text(status, style: TextStyle(
              color: enabled ? color.withValues(alpha: 0.6) : const Color(0xFF444444),
              fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Icon(enabled ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: enabled ? color : const Color(0xFF333333)),
      ]),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String sub;
  final bool value;
  final Color color;
  final ValueChanged<bool>? onChanged;
  const _ToggleRow(this.label, this.sub, this.value, this.color, this.onChanged);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: value ? color.withValues(alpha: 0.3) : const Color(0xFF1A1A1A)),
      color: value ? color.withValues(alpha: 0.04) : Colors.transparent,
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            color: value ? Colors.white : const Color(0xFF666666),
            fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 1),
        Text(sub, style: TextStyle(color: color.withValues(alpha: 0.4),
            fontSize: 9), maxLines: 2),
      ])),
      Switch(value: value, onChanged: onChanged,
          activeColor: color,
          inactiveThumbColor: const Color(0xFF333333),
          inactiveTrackColor: const Color(0xFF111111)),
    ]),
  );
}

class _SliderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final Color color;
  final ValueChanged<double> onChanged;
  const _SliderCard({required this.title, required this.subtitle,
      required this.value, required this.min, required this.max,
      required this.divisions, required this.label,
      required this.color, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.2)),
      color: color.withValues(alpha: 0.02),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: TextStyle(color: color, fontSize: 12,
          fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text('$subtitle  ($label)',
          style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 10)),
      const SizedBox(height: 4),
      Slider(
        value: value.clamp(min, max),
        min: min, max: max, divisions: divisions,
        label: label,
        activeColor: color,
        inactiveColor: color.withValues(alpha: 0.15),
        onChanged: onChanged,
      ),
    ]),
  );
}

class _FeatureToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final bool value;
  final bool locked;
  final Color color;
  final ValueChanged<bool>? onChanged;
  const _FeatureToggleRow({required this.icon, required this.label,
      required this.desc, required this.value, required this.locked,
      required this.color, this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: value && !locked
          ? color.withValues(alpha: 0.25) : const Color(0xFF181818)),
      color: value && !locked ? color.withValues(alpha: 0.03) : Colors.transparent,
    ),
    child: Row(children: [
      Icon(icon, color: locked ? const Color(0xFF333333)
          : value ? color : color.withValues(alpha: 0.3), size: 16),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: TextStyle(
              color: locked ? const Color(0xFF444444)
                  : value ? Colors.white70 : const Color(0xFF555555),
              fontSize: 11)),
          if (locked) ...[
            const SizedBox(width: 6),
            const Icon(Icons.lock, size: 10, color: Color(0xFFFFAA00)),
          ],
        ]),
        Text(desc, style: TextStyle(color: color.withValues(alpha: locked ? 0.15 : 0.35),
            fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: color,
        inactiveThumbColor: const Color(0xFF333333),
        inactiveTrackColor: const Color(0xFF111111),
      ),
    ]),
  );
}

// =============================================================================
// GAMEPAD 3D CONTROLS SETTINGS  —  V50.0
// Position, side, size and sensitivity of the floating helicopter gamepad
// =============================================================================
class _GamepadSettingsSection extends ConsumerWidget {
  final Color color;
  const _GamepadSettingsSection({required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gp  = ref.watch(gamepadSettingsProvider);
    final svc = ref.read(gamepadSettingsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Visible toggle ──────────────────────────────────────────────
        _ToggleRow('SHOW_GAMEPAD',
            'Display floating movement controls in 3D engine view.',
            gp.visible, color,
            (v) => svc.setVisible(v)),
        const SizedBox(height: 14),

        // ── Side selector ───────────────────────────────────────────────
        Row(children: [
          Text('SIDE  ', style: TextStyle(color: color, fontSize: 10,
              letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          const Spacer(),
          _SideChip('RIGHT', gp.side == GamepadSide.right, color,
              () => svc.setSide(GamepadSide.right)),
          const SizedBox(width: 8),
          _SideChip('LEFT', gp.side == GamepadSide.left, color,
              () => svc.setSide(GamepadSide.left)),
        ]),
        const SizedBox(height: 14),

        // ── Button size ─────────────────────────────────────────────────
        _SliderRow(
          label: 'BUTTON SIZE',
          value: gp.size,
          min: 0.6, max: 1.5, divisions: 9,
          displayStr: '${(gp.size * 100).round()}%',
          color: color,
          onChanged: svc.setSize,
        ),
        const SizedBox(height: 10),

        // ── Vertical position ───────────────────────────────────────────
        _SliderRow(
          label: 'VERTICAL POS',
          value: gp.verticalPosition,
          min: 0.1, max: 0.9, divisions: 16,
          displayStr: '${(gp.verticalPosition * 100).round()}%',
          color: color,
          onChanged: svc.setVerticalPosition,
        ),
        const SizedBox(height: 10),

        // ── Move sensitivity ────────────────────────────────────────────
        _SliderRow(
          label: 'MOVE SPEED',
          value: gp.moveSensitivity,
          min: 0.01, max: 0.15, divisions: 14,
          displayStr: '${(gp.moveSensitivity * 100).toStringAsFixed(0)}%',
          color: color,
          onChanged: svc.setSensitivity,
        ),
        const SizedBox(height: 14),

        // ── Preview ─────────────────────────────────────────────────────
        Center(child: Text(
          'Double-tap 3D screen to reset camera position  •  Pinch to fly forward/back',
          style: TextStyle(color: color.withValues(alpha: 0.35),
              fontSize: 9, letterSpacing: 0.5),
          textAlign: TextAlign.center,
        )),
      ]),
    );
  }
}

class _SideChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _SideChip(this.label, this.active, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: active ? color : color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)]
            : null,
      ),
      child: Text(label, style: TextStyle(
          color: active ? color : color.withValues(alpha: 0.45),
          fontSize: 10,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          letterSpacing: 1)),
    ),
  );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final int divisions;
  final String displayStr;
  final Color color;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.label, required this.value,
    required this.min, required this.max, required this.divisions,
    required this.displayStr, required this.color, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7),
            fontSize: 9, letterSpacing: 1.2)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(displayStr,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
      Slider(
        value: value.clamp(min, max),
        min: min, max: max, divisions: divisions,
        activeColor: color,
        inactiveColor: const Color(0xFF2A2A2A),
        onChanged: onChanged,
      ),
    ],
  );
}
