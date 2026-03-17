import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../services/hardware_capabilities_service.dart';
import '../widgets/back_button_top_left.dart';

class ExportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String size;
  final bool enabled;

  const ExportCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.size,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              color: enabled ? theme.colorScheme.primary : theme.colorScheme.secondary,
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
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  enabled ? Icons.download_rounded : Icons.lock_rounded,
                  color: enabled ? FalconColors.lightSecondary : theme.colorScheme.outline, // Success
                  size: 20,
                ),
                if (enabled) ...[
                   const SizedBox(height: AppSpacing.xs),
                   Text(
                     size,
                     style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                   ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SourceItem extends StatelessWidget {
  final String label;
  final String status;
  final bool active;

  const SourceItem({
    super.key,
    required this.label,
    required this.status,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: active ? FalconColors.lightSecondary : theme.colorScheme.secondary, // Success
                ),
              ),
            ],
          ),
          Switch(
            value: active,
            onChanged: (val) {},
            activeColor: FalconColors.lightSecondary, // Success
          ),
        ],
      ),
    );
  }
}

class DataVaultPage extends ConsumerWidget {
  const DataVaultPage({super.key});

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
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.lg),
                color: theme.colorScheme.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "DATA VAULT",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        Icon(Icons.security_rounded, color: FalconColors.lightSecondary, size: 28), // Accent
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "SOVEREIGN ENCRYPTION ACTIVE // AES-256-GCM",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: FalconColors.lightSecondary, // Accent
                      ),
                    ),
                  ],
                ),
              ),

              // Storage Metrics
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("ENCRYPTED STORAGE", style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary)),
                        Text("84% CAPACITY", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LinearProgressIndicator(
                      value: 0.84,
                      minHeight: 8,
                      color: theme.colorScheme.error,
                      backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Used: 1.2 GB", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface)),
                        Text("Total: 1.5 GB", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 2),

              // Active Data Streams
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Text("ACTIVE DATA STREAMS", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
                    ),
                    const SourceItem(label: "RF SIGINT LOGS", status: "STREAMING", active: true),
                    const SourceItem(label: "GEOPHYSICAL VOXELS", status: "IDLE", active: false),
                    const SourceItem(label: "PLANET HEALTH BIOMETRICS", status: "ENCRYPTING", active: true),
                    const SourceItem(label: "UWB SPATIAL MAPPING", status: "HARDWARE NOT DETECTED", active: false),
                  ],
                ),
              ),

              // Export Protocols
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("EXPORT PROTOCOLS", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
                    const SizedBox(height: AppSpacing.md),
                    const ExportCard(title: "RESEARCH BUNDLE (.PARQUET)", description: "Columnar signal data for AI training", icon: Icons.analytics_rounded, size: "42MB", enabled: true),
                    const ExportCard(title: "3D ASSET (.GLTF)", description: "Voxel mesh for CAD/BIM integration", icon: Icons.view_in_ar_rounded, size: "128MB", enabled: true),
                    const ExportCard(title: "NETWORK TRACE (.PCAPNG)", description: "Raw packet capture for SIGINT analysis", icon: Icons.radar_rounded, size: "12MB", enabled: false),
                    const ExportCard(title: "MEDICAL DOSSIER (.PDF)", description: "Biometric proxy report with HUD snapshots", icon: Icons.description_rounded, size: "4.5MB", enabled: true),
                  ],
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3), width: 2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                        minimumSize: const Size(0, 50),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text("PURGE LOCAL VAULT"),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        minimumSize: const Size(0, 50),
                      ),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text("INITIALIZE SECURE MESH TRANSFER"),
                    ),
                  ],
                ),
              ),

              // Hardware Adaptation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.background,
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: theme.colorScheme.onSurface),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("HARDWARE ADAPTATION", style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface)),
                            Text("Last scan: 2 mins ago", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                           ref.read(hardwareCapabilitiesProvider.notifier).scanHardware();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          side: BorderSide(color: theme.colorScheme.onSurface),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text("RE-SCAN"),
                      ),
                    ],
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
}
