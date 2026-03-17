import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../services/hardware_capabilities_service.dart';
import '../widgets/back_button_top_left.dart';
import '../services/stealth_service.dart';

class TacticalListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool enabled;

  const TacticalListItem({
    super.key,
    required this.icon,
    required this.title,
    required this.desc,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: enabled ? theme.colorScheme.primary : theme.colorScheme.secondary,
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: enabled ? theme.colorScheme.onPrimary : theme.colorScheme.secondary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.secondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: enabled ? theme.colorScheme.primary : theme.colorScheme.secondary),
                        ),
                        child: Text(
                          enabled ? "READY" : "LOCKED",
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: enabled ? theme.colorScheme.primary : theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    desc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right,
              color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.outline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color textColor;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.bg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          onTap: () {},
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CellularInterceptorMenuPage extends ConsumerWidget {
  const CellularInterceptorMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stealthActive = ref.watch(stealthProtocolProvider);
    final chartData = [10, 30, 25, 70, 55, 85, 35, 65, 25, 45, 35, 55, 80, 25];

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
                        "FALCON EYE",
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        "Sovereign SIGINT Suite v10",
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Icon(Icons.security, color: theme.colorScheme.onSurface, size: 24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Live RF Feed Chart
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3), width: 2),
                ),
                child: ClipRect(
                  child: Stack(
                    children: [
                      LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 13,
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: chartData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                              isCurved: true,
                              color: theme.colorScheme.onPrimary,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                              color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
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
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(alpha: 0.8),
                              border: Border.all(color: theme.colorScheme.primary),
                            ),
                            child: Text(
                              "LIVE RF FEED: 2.4GHz / 5.8GHz",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Operational Modules
              Text(
                "OPERATIONAL MODULES",
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const TacticalListItem(icon: Icons.layers, title: "GEOPHYSICAL SCANNER", desc: "Subsurface anomaly detection via RF backscatter", enabled: true),
              const TacticalListItem(icon: Icons.cell_tower, title: "CELLULAR INTERCEPTOR", desc: "Passive IMSI/TMSI traffic logging", enabled: true),
              const TacticalListItem(icon: Icons.monitor_heart, title: "PLANET HEALTH PROXY", desc: "UWB-based biometric vitals (Requires Hardware)", enabled: false),
              const TacticalListItem(icon: Icons.memory, title: "QUANTUM SPECTROMETRY", desc: "Molecular identification via NMR proxies", enabled: false),
              const TacticalListItem(icon: Icons.language, title: "MESH NETWORK NODE", desc: "Sovereign P2P encrypted relay system", enabled: true),
              const SizedBox(height: AppSpacing.md),

              // Detected Elements (Mini Module)
              Container(
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
                        Text(
                          "DETECTED ELEMENTS",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Icon(Icons.auto_graph, color: theme.colorScheme.primary, size: 18),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _buildElement(context, "Au", theme.colorScheme.primary, theme.colorScheme.onPrimary),
                        _buildElement(context, "Ag", theme.colorScheme.surface, theme.colorScheme.onSurface),
                        _buildElement(context, "Cu", theme.colorScheme.surface, theme.colorScheme.onSurface),
                        _buildElement(context, "Li", theme.colorScheme.surface, theme.colorScheme.onSurface, opacity: 0.3),
                        _buildElement(context, "Pt", theme.colorScheme.surface, theme.colorScheme.onSurface, opacity: 0.3),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Footer Actions
              Row(
                children: [
                  ActionButton(
                    icon: Icons.refresh,
                    label: "RESCAN TIER",
                    bg: theme.colorScheme.primary,
                    textColor: theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  ActionButton(
                    icon: Icons.download,
                    label: "EXPORT LOGS",
                    bg: theme.colorScheme.surface,
                    textColor: theme.colorScheme.onSurface,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Stealth Protocol Button (toggle)
              InkWell(
                onTap: () => ref.read(stealthProtocolProvider.notifier).toggle(),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: stealthActive ? theme.colorScheme.primary : theme.colorScheme.error,
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: Opacity(
                    opacity: 0.95,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.terminal, color: stealthActive ? theme.colorScheme.onPrimary : theme.colorScheme.onError, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          stealthActive ? "DEACTIVATE STEALTH PROTOCOL" : "INITIALIZE STEALTH PROTOCOL",
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: stealthActive ? theme.colorScheme.onPrimary : theme.colorScheme.onError,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
            const BackButtonTopLeft(),
          ],
        ),
      ),
    );
  }

  Widget _buildElement(BuildContext context, String text, Color bg, Color textCol, {double opacity = 1.0}) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              color: textCol,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
