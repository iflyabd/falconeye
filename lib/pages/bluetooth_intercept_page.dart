import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../services/hardware_capabilities_service.dart';
import '../widgets/back_button_top_left.dart';
import '../services/ble_service.dart';
import '../services/uwb_service.dart';

class StreamCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final String status;
  final String meta;
  final bool enabled;

  const StreamCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.status,
    required this.meta,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: active ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: active ? theme.colorScheme.primary : theme.colorScheme.secondary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                     title,
                     style: theme.textTheme.titleMedium?.copyWith(
                       color: theme.colorScheme.onSurface,
                     ),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                   Text(
                     subtitle,
                     style: theme.textTheme.bodySmall?.copyWith(
                       color: theme.colorScheme.secondary,
                     ),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? theme.colorScheme.primary : theme.colorScheme.secondaryContainer, // Success via primary
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: active ? theme.colorScheme.onPrimary : theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  meta,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceListItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final String mac;
  final bool pairing;
  final bool active;
  final String rssi;
  final int rssiVal;
  final String freq;
  final String type;
  final bool isNew;

  const DeviceListItem({
    super.key,
    required this.icon,
    required this.name,
    required this.mac,
    required this.pairing,
    required this.active,
    required this.rssi,
    required this.rssiVal,
    required this.freq,
    required this.type,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: pairing ? theme.colorScheme.secondary : theme.colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.background,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Center(
                  child: Icon(icon, color: theme.colorScheme.primary, size: 22),
                ),
              ),
              if (active)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary, // Accent
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: theme.colorScheme.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (isNew)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary, // Accent
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          "NEW",
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  mac,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.signal_cellular_alt,
                          size: 12,
                          color: rssiVal > -70 ? theme.colorScheme.primary : theme.colorScheme.error, // Success/Error
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          "$rssi dBm",
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Row(
                      children: [
                        Icon(Icons.settings_input_antenna, size: 12, color: theme.colorScheme.secondary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          freq,
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: pairing ? theme.colorScheme.secondary : theme.colorScheme.primary, // Tonal/Primary
                  side: BorderSide(color: pairing ? theme.colorScheme.secondary : theme.colorScheme.primary),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(pairing ? "STOP" : "CONNECT"),
              ),
              const SizedBox(height: AppSpacing.xs),
               Text(
                 type,
                 style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
               ),
            ],
          ),
        ],
      ),
    );
  }
}

class BluetoothInterceptPage extends ConsumerWidget {
  const BluetoothInterceptPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chartData = [20, 45, 30, 80, 60, 90, 40, 70, 55, 100, 80, 40, 30, 60];

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "SIGNAL INTERCEPT",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      FutureBuilder<bool>(
                        future: UwbService.isUwbSupported(),
                        builder: (context, snap) {
                          final uwb = snap.data == true;
                          return Row(
                            children: [
                              Text(
                                "PAN & ACOUSTIC SURVEILLANCE",
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: uwb ? FalconColors.lightSecondary : theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                ),
                                child: Text(
                                  uwb ? 'UWB SUPPORTED' : 'UWB N/A',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: uwb ? theme.colorScheme.onSecondary : theme.colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: theme.colorScheme.primary),
                      boxShadow: [
                         BoxShadow(color: theme.shadowColor.withValues(alpha: 0.1), blurRadius: 4),
                      ],
                    ),
                    child: Center(
                      child: Icon(Icons.security, color: theme.colorScheme.primary, size: 24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Chart Area
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  boxShadow: [
                     BoxShadow(color: theme.shadowColor.withValues(alpha: 0.1), blurRadius: 4),
                  ],
                ),
                child: ClipRect(
                  child: Stack(
                    children: [
                      LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: chartData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                              isCurved: true,
                              color: theme.colorScheme.primary,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("2.4GHz Spectrum Analysis", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                                  Text("Interference Level: Low", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppRadius.xs),
                                  border: Border.all(color: theme.colorScheme.primary),
                                ),
                                child: Text("STABLE", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Active Interceptions
              Text("ACTIVE INTERCEPTIONS", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.md),
              const StreamCard(icon: Icons.mic_none, title: "Mic Uplink", subtitle: "Capturing ambient acoustics via BLE-HID", active: true, status: "LIVE", meta: "48kHz / 24bit", enabled: true),
              const StreamCard(icon: Icons.spatial_audio, title: "Spatial Triangulation", subtitle: "Requires UWB chipset for AoA tracking", active: false, status: "LOCKED", meta: "N/A", enabled: false),

              const SizedBox(height: AppSpacing.md),

              // Available Devices
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                       Text("AVAILABLE DEVICES", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                       const SizedBox(width: AppSpacing.sm),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                         decoration: BoxDecoration(
                           color: theme.colorScheme.primary,
                           borderRadius: BorderRadius.circular(AppRadius.full),
                         ),
                         child: Text(ref.watch(bleServiceProvider).devices.length.toString(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                       ),
                    ],
                  ),
                  IconButton(onPressed: () {}, icon: Icon(Icons.filter_list, color: theme.colorScheme.primary, size: 20)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              
              ...ref.watch(bleServiceProvider).devices.map((d) => DeviceListItem(
                    icon: Icons.bluetooth,
                    name: d.name,
                    mac: d.id,
                    pairing: false,
                    active: d.connectable,
                    rssi: d.rssi.toString(),
                    rssiVal: d.rssi,
                    freq: '2.4GHz',
                    type: 'BLE',
                    isNew: false,
                  )),

              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                   foregroundColor: theme.colorScheme.primary,
                   side: BorderSide(color: theme.colorScheme.primary),
                   minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text("RESCAN HARDWARE"),
              ),
              const SizedBox(height: AppSpacing.md),

              // Footer Info
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: theme.colorScheme.error),
                ),
                child: Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Icon(Icons.warning_amber, color: theme.colorScheme.error, size: 20),
                     const SizedBox(width: AppSpacing.md),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text("Sovereignty Protocol", style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                           const SizedBox(height: AppSpacing.xs),
                           Text("All interceptions are stored locally in the encrypted vault. No cloud sync active.", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                         ],
                       ),
                     ),
                   ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
            const BackButtonTopLeft(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final svc = ref.read(bleServiceProvider.notifier);
          final scanning = ref.read(bleServiceProvider).scanning;
          if (scanning) {
            svc.stopScan();
          } else {
            svc.startScan();
          }
        },
        backgroundColor: ref.watch(bleServiceProvider).scanning ? theme.colorScheme.error : theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: Icon(ref.watch(bleServiceProvider).scanning ? Icons.stop_circle : Icons.search),
        label: Text(ref.watch(bleServiceProvider).scanning ? "STOP SCAN" : "SCAN BLE"),
      ),
    );
  }
}
