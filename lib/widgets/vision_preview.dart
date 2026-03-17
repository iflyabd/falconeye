import 'package:flutter/material.dart';
import '../theme.dart';

/// Minimal, dependency-free preview placeholder.
/// The project moved to a wave-based preview inside VisionConfiguratorPage,
/// so this widget exists only to satisfy older imports without extra packages.
class VisionPreview extends StatelessWidget {
  final double intensity; // 0..1
  const VisionPreview({super.key, this.intensity = 1.0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4), width: 1),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off, color: theme.colorScheme.outline, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Legacy Preview Disabled',
            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Use the Wave Twin preview in Config page',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
