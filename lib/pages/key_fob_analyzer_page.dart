import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../widgets/falcon_side_panel.dart';
import '../services/hardware_capabilities_service.dart';
import '../widgets/back_button_top_left.dart';
import '../services/nfc_service.dart';

class CarKeyCard extends StatelessWidget {
  final IconData icon;
  final String brand;
  final String model;
  final String freq;
  final String protocol;
  final String rssi;
  final bool detected;
  final bool isLocked;

  const CarKeyCard({
    super.key,
    required this.icon,
    required this.brand,
    required this.model,
    required this.freq,
    required this.protocol,
    required this.rssi,
    required this.detected,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: detected ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: detected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3)), // Accent
          boxShadow: detected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2), // Accent
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: detected ? theme.colorScheme.primary : theme.colorScheme.secondary), // Accent
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: detected ? theme.colorScheme.primary : theme.colorScheme.secondary, // Accent
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
                        brand,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        model,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: detected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant, // Success
                    border: Border.all(color: detected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3)), // Success
                  ),
                  child: Text(
                    detected ? "SIGNAL DETECTED" : "SCANNING...",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: detected ? theme.colorScheme.onPrimary : theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
            Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3), thickness: 0.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("FREQUENCY", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                    Text(freq, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("PROTOCOL", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                    Text(protocol, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("STRENGTH", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                    Text(rssi, style: theme.textTheme.bodyMedium?.copyWith(color: detected ? theme.colorScheme.primary : theme.colorScheme.secondary)), // Success
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: detected ? 1.0 : 0.5,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                         border: Border.all(color: detected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isLocked ? Icons.lock_open : Icons.lock, size: 18, color: theme.colorScheme.onSurface),
                            const SizedBox(width: AppSpacing.sm),
                            Text(isLocked ? "UNLOCK" : "LOCK", style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Opacity(
                    opacity: detected ? 1.0 : 0.5,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                         border: Border.all(color: detected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.electric_car, size: 18, color: theme.colorScheme.onSurface),
                            const SizedBox(width: AppSpacing.sm),
                            Text("TRUNK", style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Opacity(
                  opacity: detected ? 1.0 : 0.5,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.error),
                    ),
                    child: Center(
                      child: Icon(Icons.notification_important, size: 18, color: theme.colorScheme.error),
                    ),
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

class KeyFobAnalyzerPage extends ConsumerWidget {
  const KeyFobAnalyzerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final capabilities = ref.watch(hardwareCapabilitiesProvider);
    final chartData = [10, 40, 15, 80, 20, 30, 90, 40, 10, 50];

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.colorScheme.primary, width: 2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Text(
                        "KEY FOB ANALYZER",
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                Text(
                  "SUB-GHZ ROLLING CODE SNIFFER",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary, // Accent
                  ),
                ),
                    ],
                  ),
                  Icon(Icons.minor_crash, color: theme.colorScheme.primary, size: 28),
                ],
              ),
            ),

            // NFC status
            Consumer(
              builder: (context, ref, _) {
                final nfc = ref.watch(nfcProvider);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('NFC STATUS', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                      Row(
                        children: [
                          Icon(nfc.supported ? Icons.nfc : Icons.block, size: 16, color: nfc.supported ? theme.colorScheme.primary : theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            nfc.scanning
                                ? 'Scanning... Tap a fob/card'
                                : (nfc.enabled
                                    ? (nfc.lastTag == null ? nfc.statusMessage : 'Last: ${nfc.lastTag!.tech} ${nfc.lastTag!.uidHex}')
                                    : 'NFC disabled'),
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // Live Spectrum
            Container(
              height: 100,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("LIVE SPECTRUM (315/433/868 MHz)", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                      Text("ACTIVE", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)), // Success
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 9,
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: chartData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                              isCurved: true,
                              color: theme.colorScheme.primary, // Accent
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: theme.colorScheme.primary.withValues(alpha: 0.2), // Accent
                              ),
                            ),
                          ],
                        ),
                      ),
                  ),
                ],
              ),
            ),

            // Car Keys List
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    // Last scanned NFC tag (real)
                    Consumer(builder: (context, ref, _) {
                      final nfc = ref.watch(nfcProvider);
                      if (nfc.lastTag == null) return const SizedBox.shrink();
                      final t = nfc.lastTag!;
                       return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                           color: theme.colorScheme.surface,
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.nfc, color: theme.colorScheme.primary),
                                const SizedBox(width: AppSpacing.md),
                                Text('LAST SCANNED TAG', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text('UID: ${t.uidHex}', style: theme.textTheme.bodyMedium),
                            Text('Tech: ${t.tech}', style: theme.textTheme.bodyMedium),
                            Text('NDEF: ${t.ndefAvailable ? 'Yes' : 'No'}', style: theme.textTheme.bodyMedium),
                            if (t.ndefRecords.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text('Records:', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                              for (final r in t.ndefRecords)
                                Text('• $r', style: theme.textTheme.bodySmall),
                            ],
                          ],
                        ),
                      );
                    }),

                    const CarKeyCard(
                      icon: Icons.directions_car,
                      brand: "TESLA MODEL 3",
                      model: "ID: 66-B2-1A • PROXIMITY",
                      freq: "2.4 GHz (UWB)",
                      protocol: "BLE / UWB Relay",
                      rssi: "-42 dBm",
                      detected: true,
                      isLocked: true,
                    ),
                    const CarKeyCard(
                      icon: Icons.directions_car,
                      brand: "MERCEDES-BENZ",
                      model: "G-WAGON • FBS4 SYSTEM",
                      freq: "433.92 MHz",
                      protocol: "Rolling Code v3",
                      rssi: "-58 dBm",
                      detected: true,
                      isLocked: false,
                    ),
                    const CarKeyCard(
                      icon: Icons.directions_car,
                      brand: "BMW M4",
                      model: "COMFORT ACCESS 2.0",
                      freq: "315.00 MHz",
                      protocol: "AES-128 Encrypted",
                      rssi: "-89 dBm",
                      detected: true,
                      isLocked: true,
                    ),
                    const CarKeyCard(
                      icon: Icons.directions_car,
                      brand: "TOYOTA RAV4",
                      model: "DENSO SYSTEM",
                      freq: "433.92 MHz",
                      protocol: "Scanning...",
                      rssi: "N/A",
                      detected: false,
                      isLocked: true,
                    ),

                    // Brute Force Warning
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                      ),
                      child: Opacity(
                        opacity: 0.5,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_reset, color: theme.colorScheme.secondary),
                                const SizedBox(width: AppSpacing.md),
                                Text("ADVANCED BRUTEFORCE MODULE", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text("Requires Root & External CC1101 Transceiver", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: theme.colorScheme.primary, size: 16), // Success
                      const SizedBox(width: AppSpacing.sm),
                      Text("ENCRYPTION: BYPASSED", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)), // Success
                    ],
                  ),
                  Text("FIELD STEALTH: ON", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface)),
                ],
              ),
            ),
          ],
        ),
            const BackButtonTopLeft(),
const FalconPanelTrigger(top: 90),
          ],
        ),
      ),
      floatingActionButton: Consumer(
        builder: (context, ref, _) {
          final nfc = ref.watch(nfcProvider);
          return FloatingActionButton.extended(
            onPressed: () async {
              final svc = ref.read(nfcProvider.notifier);
              if (nfc.scanning) {
                await svc.stopScanning();
              } else {
                await svc.startScanning();
              }
            },
            backgroundColor: theme.colorScheme.primary, // Accent
            foregroundColor: theme.colorScheme.onPrimary,
            icon: Icon(nfc.scanning ? Icons.stop : Icons.radar),
            label: Text(nfc.scanning ? 'STOP NFC SCAN' : 'SCAN FOR FOBS'),
          );
        },
      ),
    );
  }
}
