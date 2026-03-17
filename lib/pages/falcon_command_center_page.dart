import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../widgets/falcon_side_panel.dart';
import '../services/hardware_capabilities_service.dart';
import '../widgets/back_button_top_left.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.bg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class TargetCard extends StatelessWidget {
  final String id;
  final String deviceType;
  final String status;
  final Color statusBg;
  final Color statusText;
  final String signal;
  final String vitals;
  final bool enabled;

  const TargetCard({
    super.key,
    required this.id,
    required this.deviceType,
    required this.status,
    required this.statusBg,
    required this.statusText,
    required this.signal,
    required this.vitals,
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
          border: Border.all(color: Colors.black, width: 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        id,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        deviceType,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: status, bg: statusBg, textColor: statusText),
              ],
            ),
            const Divider(color: Colors.black, thickness: 2),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SIGNAL STRENGTH", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Icon(Icons.signal_cellular_alt, size: 16, color: theme.colorScheme.onSurface),
                          const SizedBox(width: AppSpacing.xs),
                          Text(signal, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("BIO-SYNC", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Icon(Icons.favorite, size: 16, color: theme.colorScheme.error),
                          const SizedBox(width: AppSpacing.xs),
                          Text(vitals, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (enabled) ...[
               const SizedBox(height: AppSpacing.md),
               ElevatedButton(
                 onPressed: () {},
                 style: ElevatedButton.styleFrom(
                   backgroundColor: theme.colorScheme.primary,
                   foregroundColor: theme.colorScheme.onPrimary,
                   shape: const RoundedRectangleBorder(),
                   minimumSize: const Size.fromHeight(40),
                 ),
                 child: const Text("DEEP SCAN"),
               ),
            ],
          ],
        ),
      ),
    );
  }
}

class MeshNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const MeshNode({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: active ? 1.0 : 0.4,
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? theme.colorScheme.primary : theme.colorScheme.secondary,
              size: 24,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FalconCommandCenterPage extends ConsumerWidget {
  const FalconCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final capabilities = ref.watch(hardwareCapabilitiesProvider);

    // Dummy chart data
    final chartData = [40, 70, 50, 90, 60, 80, 95];

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
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: FalconColors.lightPrimary,
                  border: Border(bottom: BorderSide(color: Colors.black, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "FALCON COMMAND",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: FalconColors.lightOnPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: Colors.black,
                          child: Text(
                            "MESH: ACTIVE",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: FalconColors.lightPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "MULTI-TARGET SIGINT & BIO-MONITORING GRID",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: FalconColors.lightOnPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Network Topology
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("NETWORK TOPOLOGY",
                        style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: AppSpacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: const [
                          MeshNode(icon: Icons.hub, label: "GATEWAY", active: true),
                          MeshNode(icon: Icons.router, label: "NODE-01", active: true),
                          MeshNode(icon: Icons.memory, label: "NODE-02", active: true),
                          MeshNode(icon: Icons.sensors, label: "UWB-ARRAY", active: false),
                          MeshNode(icon: Icons.satellite_alt, label: "SAT-LINK", active: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Live Chart
               Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: const Border(bottom: BorderSide(color: Colors.black, width: 2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text("AGGREGATE SIGNAL DENSITY",
                            style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                         Text("LIVE STREAM",
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 120,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: chartData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                              isCurved: true,
                              color: theme.colorScheme.primary,
                              barWidth: 4,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Active Targets
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("ACTIVE TARGETS (04)",
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                        IconButton(onPressed: () {}, icon: Icon(Icons.filter_list, color: theme.colorScheme.onSurface)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    
                    TargetCard(
                      id: "TARGET-ALPHA (LEADER)",
                      deviceType: "SAMSUNG S24 ULTRA (ROOTED)",
                      status: "ONLINE",
                      statusBg: FalconColors.lightSecondary, // Success
                      statusText: theme.colorScheme.onSurface,
                      signal: "-42 dBm",
                      vitals: "72 BPM",
                      enabled: true,
                    ),
                    TargetCard(
                      id: "TARGET-BRAVO",
                      deviceType: "PIXEL 8 PRO (SHIZUKU)",
                      status: "STABLE",
                      statusBg: theme.colorScheme.primary,
                      statusText: theme.colorScheme.onPrimary,
                      signal: "-58 dBm",
                      vitals: "68 BPM",
                      enabled: true,
                    ),
                     const TargetCard(
                      id: "TARGET-GAMMA (UWB)",
                      deviceType: "IPHONE PROXY NODE",
                      status: "UNSUPPORTED",
                      statusBg: Color(0xFF555555),
                      statusText: Colors.white,
                      signal: "N/A",
                      vitals: "N/A",
                      enabled: false,
                    ),

                    // Warning for Target Gamma
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE600),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.black),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              "TARGET-GAMMA: Hardware mismatch. UWB chipset not detected on local node for spatial ranging.",
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

               // Footer Actions
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: const Border(top: BorderSide(color: Colors.black, width: 4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error, width: 2),
                          shape: const RoundedRectangleBorder(),
                          minimumSize: const Size(0, 50),
                        ),
                        icon: const Icon(Icons.warning),
                        label: const Text("BROADCAST ALERT"),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: const RoundedRectangleBorder(),
                          minimumSize: const Size(0, 50),
                        ),
                        icon: const Icon(Icons.sync),
                        label: const Text("SYNC ALL NODES"),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
            const BackButtonTopLeft(),
const FalconPanelTrigger(top: 90),
          ],
        ),
      ),
    );
  }
}
