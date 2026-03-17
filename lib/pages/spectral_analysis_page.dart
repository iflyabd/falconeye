import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../widgets/falcon_side_panel.dart';
import '../services/hardware_capabilities_service.dart';
import '../widgets/back_button_top_left.dart';

class HardwareStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool active;

  const HardwareStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(icon, size: 16, color: active ? FalconColors.lightSecondary : theme.colorScheme.secondary), // Success
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: active ? theme.colorScheme.onSurface : theme.colorScheme.secondary,
                    ),
                    overflow: TextOverflow.ellipsis,
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

class FrequencyPreset extends StatelessWidget {
  final String freq;
  final String label;
  final bool selected;

  const FrequencyPreset({
    super.key,
    required this.freq,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: selected ? theme.colorScheme.primary : theme.colorScheme.surface,
        border: Border.all(color: selected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            freq,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class ProtocolChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool detected;
  final bool supported;

  const ProtocolChip({
    super.key,
    required this.name,
    required this.icon,
    required this.detected,
    required this.supported,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: supported ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(
            color: detected ? FalconColors.lightSecondary : theme.colorScheme.outline.withValues(alpha: 0.3), // Success
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: detected ? FalconColors.lightSecondary : theme.colorScheme.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              name,
              style: theme.textTheme.labelMedium?.copyWith(
                color: detected ? FalconColors.lightSecondary : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpectralAnalysisPage extends ConsumerWidget {
  const SpectralAnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final capabilities = ref.watch(hardwareCapabilitiesProvider);

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
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: theme.colorScheme.onSurface, width: 2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SPECTRAL ANALYSIS",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              "SDR WIDEBAND MONITOR // OTG-ACTIVE",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          color: theme.colorScheme.primary,
                          child: Text(
                            "LIVE STREAM",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Hardware Status
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: const [
                        HardwareStat(
                          label: "SDR ENGINE",
                          value: "RTL-SDR V3",
                          icon: Icons.usb_rounded,
                          active: true,
                        ),
                        SizedBox(width: AppSpacing.md),
                        HardwareStat(
                          label: "ANTENNA",
                          value: "WHIP-GP",
                          icon: Icons.settings_input_antenna_rounded,
                          active: true,
                        ),
                        SizedBox(width: AppSpacing.md),
                        HardwareStat(
                          label: "UPCONVERTER",
                          value: "DISABLED",
                          icon: Icons.transform_rounded,
                          active: false,
                        ),
                      ],
                    ),
                  ),

                  // Waterfall Display (Simulated with Gradients)
                  Container(
                    height: 240,
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: const Color(0xFF050505),
                      border: Border.all(color: theme.colorScheme.onSurface, width: 2),
                    ),
                    child: ClipRect(
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, Color(0xFF00FFFF), Color(0xFFFF0000), Color(0xFF00FFFF)],
                                      stops: [0.0, 0.3, 0.5, 1.0],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                              ),
                               Expanded(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, Color(0xFF00FFFF), Color(0xFFFF6B00), Color(0xFF00FFFF)],
                                      stops: [0.1, 0.4, 0.6, 0.9],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                               ),
                               Expanded(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, Color(0xFF00FFFF), Color(0xFFFF0000), Color(0xFF00FFFF)],
                                      stops: [0.2, 0.5, 0.8, 1.0],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                               ),
                               Expanded(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, Color(0xFF00FFFF), Color(0xFFFF6B00), Color(0xFF00FFFF)],
                                      stops: [0.0, 0.2, 0.5, 0.8],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                               ),
                               Expanded(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, Color(0xFF00FFFF), Color(0xFFFF0000)],
                                      stops: [0.3, 0.6, 1.0],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                               ),
                            ],
                          ),
                          // Overlay Scan Line
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 2,
                              color: FalconColors.lightSecondary,
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 20),
                            ),
                          ),
                          // Axis Labels
                          Positioned(
                            bottom: AppSpacing.sm,
                            left: AppSpacing.sm,
                            right: AppSpacing.sm,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("104.1 MHz", style: theme.textTheme.labelSmall?.copyWith(color: FalconColors.lightPrimary)),
                                Text("105.5 MHz", style: theme.textTheme.labelSmall?.copyWith(color: FalconColors.lightPrimary)),
                                Text("106.9 MHz", style: theme.textTheme.labelSmall?.copyWith(color: FalconColors.lightPrimary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Frequency Tuner
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Text(
                          "105.500.000",
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                            fontSize: 48,
                          ),
                        ),
                        Text(
                          "TUNED FREQUENCY (Hz) // FM BROADCAST",
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Presets
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("QUICK PRESETS",
                            style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
                        const SizedBox(height: AppSpacing.md),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: const [
                              FrequencyPreset(freq: "1090 MHz", label: "ADS-B AIRCRAFT", selected: false),
                              SizedBox(width: AppSpacing.md),
                              FrequencyPreset(freq: "105.5 MHz", label: "FM RADIO", selected: true),
                              SizedBox(width: AppSpacing.md),
                              FrequencyPreset(freq: "433 MHz", label: "IOT / ISM", selected: false),
                              SizedBox(width: AppSpacing.md),
                              FrequencyPreset(freq: "868 MHz", label: "LORA / MESH", selected: false),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Protocol Differentiation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("PROTOCOL DIFFERENTIATION",
                            style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: const [
                            ProtocolChip(name: "WFM ANALYZER", icon: Icons.radio_rounded, detected: true, supported: true),
                            ProtocolChip(name: "ADS-B DECODER", icon: Icons.flight_takeoff_rounded, detected: false, supported: true),
                            ProtocolChip(name: "TETRA/DMR", icon: Icons.security_rounded, detected: false, supported: false),
                            ProtocolChip(name: "SIGINT VOX", icon: Icons.record_voice_over_rounded, detected: false, supported: true),
                            ProtocolChip(name: "GSM SNIFFER", icon: Icons.cell_tower_rounded, detected: false, supported: false),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 60,
                            color: theme.colorScheme.onSurface,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow_rounded, color: theme.colorScheme.surface),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    "START SWEEP",
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.surface,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.onSurface, width: 2),
                          ),
                          child: Center(
                            child: Icon(Icons.save_rounded, color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer Config Stats
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.lg),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(top: BorderSide(color: theme.colorScheme.onSurface, width: 2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("NOISE FLOOR", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                            Text("-112 dBm",
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: FalconColors.lightSecondary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        LinearProgressIndicator(
                          value: 0.3,
                          color: FalconColors.lightSecondary,
                          backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.3),
                          minHeight: 4,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("CPU LOAD (DSP)", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                            Text("42%",
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
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
