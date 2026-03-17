import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../services/hardware_capabilities_service.dart';
import '../widgets/back_button_top_left.dart';

class SignalLogEntry extends StatelessWidget {
  final String freq;
  final String id;
  final String type;
  final IconData icon;
  final bool captured;

  const SignalLogEntry({
    super.key,
    required this.freq,
    required this.id,
    required this.type,
    required this.icon,
    required this.captured,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  freq,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                Text(
                  id,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            type,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Icon(
            icon,
            color: captured ? theme.colorScheme.primary : theme.colorScheme.outline,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class ActionTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const ActionTab({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primary.withValues(alpha: 0.07) : theme.colorScheme.surface,
          border: Border.all(color: active ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: active ? theme.colorScheme.primary : theme.colorScheme.secondary,
              size: 20,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: active ? theme.colorScheme.onSurface : theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RFLockpickPage extends ConsumerWidget {
  const RFLockpickPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final capabilities = ref.watch(hardwareCapabilitiesProvider);
    final chartData = [10, 80, 15, 90, 12, 75, 20, 85, 15, 95];

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "RF LOCKPICK",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              "NFC / SUB-GHZ / RFID REPLAY",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.nfc, size: 24),
                          color: theme.colorScheme.onSurface,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),

                  // Signal Visualizer
                  Container(
                    height: 180,
                    margin: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                    ),
                    child: ClipRect(
                      child: Stack(
                        children: [
                          LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: true),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              minX: 0,
                              maxX: 9,
                              minY: 0,
                              maxY: 100,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: chartData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                                  isCurved: false,
                                  color: theme.colorScheme.primary,
                                  barWidth: 2,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.07),
                                  border: Border.all(color: theme.colorScheme.primary),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.radio, color: theme.colorScheme.primary, size: 20),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text("433.92 MHz", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("OOK / PWM", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                                  Text("SIGNAL CAPTURED", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Action Toolbar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Row(
                      children: const [
                        ActionTab(icon: Icons.fiber_manual_record, label: "RECORD", active: true),
                        SizedBox(width: 8),
                        ActionTab(icon: Icons.play_arrow, label: "REPLAY", active: false),
                        SizedBox(width: 8),
                        ActionTab(icon: Icons.save, label: "SAVE", active: false),
                        SizedBox(width: 8),
                        ActionTab(icon: Icons.delete_sweep, label: "CLEAR", active: false),
                      ],
                    ),
                  ),

                  // Captured Logs
                  Container(
                    margin: const EdgeInsets.all(AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("CAPTURED LOGS", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
                            Text("3 NEW SIGNALS", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Column(
                          children: const [
                            SignalLogEntry(freq: "NFC MIFARE DESFire", id: "UID: 04:A2:F1:7B:22:90", type: "13.56 MHz", icon: Icons.check_circle, captured: true),
                            Divider(height: 8),
                            SignalLogEntry(freq: "Sub-GHz Rolling", id: "RAW_DATA_0x7F21A9", type: "433.92 MHz", icon: Icons.sensors, captured: true),
                            Divider(height: 8),
                            SignalLogEntry(freq: "RFID HID Prox", id: "FAC: 128 ID: 44092", type: "125 kHz", icon: Icons.lock_open, captured: false),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Terminal Output
                  Container(
                    margin: const EdgeInsets.all(AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("> ATTACHING TO NFC_CHIPSET... OK", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                        const SizedBox(height: AppSpacing.xs),
                        Text("> LISTENING ON 433.92MHZ (OOK MODULATION)", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface)),
                        const SizedBox(height: AppSpacing.xs),
                        Text("> PREAMBLE DETECTED: 0xAAAAAA", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                        const SizedBox(height: AppSpacing.xs),
                        Text("> WARNING: ROLLING CODE DETECTED - REPLAY MAY FAIL", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                        const SizedBox(height: AppSpacing.xs),
                        Text("> BUFFER READY FOR REPLAY ATTACK...", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Attack Actions
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.onSurface,
                              side: BorderSide(color: theme.colorScheme.onSurface),
                              minimumSize: const Size(0, 56),
                            ),
                            child: const Text("BRUTEFORCE ATTACK"),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              minimumSize: const Size(0, 56),
                            ),
                            child: const Text("EXECUTE REPLAY"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const BackButtonTopLeft(),
          ],
        ),
      ),
    );
  }
}
