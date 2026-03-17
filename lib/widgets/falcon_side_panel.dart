import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/features_provider.dart';
import '../services/twin_config_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON SIDE PANEL  V48.1
//  Transparent slide-from-right panel with all feature toggles
// ═══════════════════════════════════════════════════════════════════════════════

/// The trigger button shown in the top-right corner of any page
class FalconPanelTrigger extends ConsumerWidget {
  final double top;
  const FalconPanelTrigger({super.key, this.top = 80});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(featuresProvider);
    final color = features.primaryColor;
    return Positioned(
      top: top,
      right: 0,
      child: GestureDetector(
        onTap: () => _FalconSidePanelRoute.show(context),
        child: Container(
          width: 38,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            border: Border(
              left: BorderSide(color: color, width: 2),
              top: BorderSide(color: color, width: 1),
              bottom: BorderSide(color: color, width: 1),
            ),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, color: color, size: 15),
              const SizedBox(height: 4),
              RotatedBox(
                quarterTurns: 1,
                child: Text(
                  'OPT',
                  style: TextStyle(
                    color: color,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Show the panel as an overlay route ───────────────────────────────────────
class _FalconSidePanelRoute {
  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim, secondAnim) => const _FalconSidePanelPage(),
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }
}

// ─── Side Panel Page ──────────────────────────────────────────────────────────
class _FalconSidePanelPage extends ConsumerStatefulWidget {
  const _FalconSidePanelPage();

  @override
  ConsumerState<_FalconSidePanelPage> createState() =>
      _FalconSidePanelPageState();
}

class _FalconSidePanelPageState extends ConsumerState<_FalconSidePanelPage> {
  bool _showThemes = false;
  String? _expandedSection;

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(featuresProvider);
    final service = ref.read(featuresProvider.notifier);
    final color = features.primaryColor;
    final screenW = MediaQuery.of(context).size.width;
    final panelW = (screenW * 0.82).clamp(280.0, 360.0);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: panelW,
          height: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.92),
              border: Border(left: BorderSide(color: color, width: 2)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showThemes
                    ? _ThemeSelector(
                        key: const ValueKey('themes'),
                        features: features,
                        service: service,
                        onBack: () => setState(() => _showThemes = false),
                      )
                    : _FeatureList(
                        key: const ValueKey('features'),
                        features: features,
                        service: service,
                        expandedSection: _expandedSection,
                        onSectionTap: (s) => setState(() =>
                            _expandedSection =
                                _expandedSection == s ? null : s),
                        onShowThemes: () => setState(() => _showThemes = true),
                        onClose: () => Navigator.of(context).pop(),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Feature List ─────────────────────────────────────────────────────────────
class _FeatureList extends ConsumerWidget {
  final FeaturesState features;
  final FeaturesService service;
  final String? expandedSection;
  final void Function(String) onSectionTap;
  final VoidCallback onShowThemes;
  final VoidCallback onClose;

  const _FeatureList({
    super.key,
    required this.features,
    required this.service,
    required this.expandedSection,
    required this.onSectionTap,
    required this.onShowThemes,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = features.primaryColor;

    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────
        _PanelHeader(
          title: 'FALCON OPTIONS',
          subtitle: 'V48.1 · SOVEREIGN UNIVERSAL EDITION',
          color: color,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderBtn(
                icon: Icons.palette,
                label: 'THEMES',
                color: color,
                onTap: onShowThemes,
              ),
              const SizedBox(width: 8),
              _HeaderBtn(
                icon: Icons.close,
                label: 'CLOSE',
                color: color.withValues(alpha: 0.7),
                onTap: onClose,
              ),
            ],
          ),
        ),

        // ── Feature sections ────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              // All-on / All-off strip
              _QuickActionsRow(features: features, service: service, color: color),
              const SizedBox(height: 4),

              for (final section in FKey.sections) ...[
                _SectionHeader(
                  section: section,
                  isExpanded: expandedSection == section.title || expandedSection == null,
                  onTap: () => onSectionTap(section.title),
                ),
                if (expandedSection == section.title || expandedSection == null)
                  for (final key in section.keys)
                    _FeatureToggleRow(
                      featureKey: key,
                      features: features,
                      service: service,
                    ),
              ],

              // Reset button
              const SizedBox(height: 12),
              _ResetRow(service: service, color: color),

              // ── V48.1 Quick Twin Controls ──────────────────────────────
              const SizedBox(height: 12),
              _QuickTwinControls(color: color),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Theme Selector ───────────────────────────────────────────────────────────
class _ThemeSelector extends StatelessWidget {
  final FeaturesState features;
  final FeaturesService service;
  final VoidCallback onBack;

  const _ThemeSelector({
    super.key,
    required this.features,
    required this.service,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final color = features.primaryColor;

    return Column(
      children: [
        _PanelHeader(
          title: 'SELECT THEME',
          subtitle: '${FalconTheme.values.length} AVAILABLE',
          color: color,
          trailing: _HeaderBtn(
            icon: Icons.arrow_back,
            label: 'BACK',
            color: color,
            onTap: onBack,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final theme in FalconTheme.values)
                _ThemeCard(
                  theme: theme,
                  isActive: features.theme == theme,
                  onTap: () => service.setTheme(theme),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Theme changes the primary accent color throughout the app. '
                  'Vision modes keep their own colors when active.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────
class _PanelHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final Widget trailing;

  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.track_changes, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HeaderBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final FeaturesState features;
  final FeaturesService service;
  final Color color;

  const _QuickActionsRow({
    required this.features,
    required this.service,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: _QuickBtn(
              label: 'ALL ON',
              color: color,
              onTap: () {
                for (final s in FKey.sections) {
                  for (final k in s.keys) {
                    final meta = featureMeta(k);
                    if (!meta.requiresRoot || features.hasRoot) {
                      service.toggle(k, value: true);
                    }
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickBtn(
              label: 'ALL OFF',
              color: Colors.white38,
              onTap: () {
                for (final s in FKey.sections) {
                  for (final k in s.keys) {
                    service.toggle(k, value: false);
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickBtn(
              label: 'DEFAULTS',
              color: Colors.white38,
              onTap: service.resetToDefaults,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final FeatureSection section;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.section,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = section.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Icon(section.icon, color: color, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                section.title,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: color.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureToggleRow extends StatelessWidget {
  final String featureKey;
  final FeaturesState features;
  final FeaturesService service;

  const _FeatureToggleRow({
    required this.featureKey,
    required this.features,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final meta = featureMeta(featureKey);
    final isOn = features[featureKey];
    final isRootLocked = meta.requiresRoot && !features.hasRoot;
    final accentColor = features.primaryColor;

    return Opacity(
      opacity: isRootLocked ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: isRootLocked
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🔒 ${meta.label} requires root access',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.red.shade900,
                    behavior: SnackBarBehavior.floating,
                  ),
                )
            : null,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: accentColor.withValues(alpha: 0.07), width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                meta.icon,
                color: isOn ? accentColor : Colors.white24,
                size: 15,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meta.label,
                            style: TextStyle(
                              color: isOn ? Colors.white : Colors.white54,
                              fontSize: 12,
                              fontWeight: isOn ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (meta.requiresRoot)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange, width: 0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text(
                              'ROOT',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      meta.description,
                      style: const TextStyle(color: Colors.white24, fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // The toggle switch
              Transform.scale(
                scale: 0.78,
                child: Switch(
                  value: isOn,
                  activeThumbColor: accentColor,
                  activeTrackColor: accentColor.withValues(alpha: 0.25),
                  inactiveThumbColor: Colors.white24,
                  inactiveTrackColor: Colors.white12,
                  onChanged: isRootLocked
                      ? null
                      : (v) => service.toggle(featureKey, value: v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final FalconTheme theme;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? theme.primary.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: isActive ? theme.primary : theme.primary.withValues(alpha: 0.25),
            width: isActive ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: theme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: theme.background,
                border: Border.all(color: theme.primary, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(theme.icon, color: theme.primary, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.label,
                    style: TextStyle(
                      color: isActive ? theme.primary : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      for (final c in [theme.primary, theme.secondary, theme.background])
                        Container(
                          width: 10, height: 10,
                          margin: const EdgeInsets.only(right: 3, top: 2),
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                                color: Colors.white24, width: 0.5),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle, color: theme.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ResetRow extends StatelessWidget {
  final FeaturesService service;
  final Color color;

  const _ResetRow({required this.service, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: OutlinedButton.icon(
        onPressed: () {
          service.resetToDefaults();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('All features reset to defaults'),
              backgroundColor: Colors.grey.shade900,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        icon: Icon(Icons.restore, color: color, size: 14),
        label: Text(
          'RESET ALL TO DEFAULTS',
          style: TextStyle(color: color, fontSize: 11, letterSpacing: 0.5),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

// ─── V48.1 Quick Twin Controls (in side panel) ─────────────────────────────────
class _QuickTwinControls extends ConsumerWidget {
  final Color color;
  const _QuickTwinControls({required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(twinConfigProvider);
    final notifier = ref.read(twinConfigProvider.notifier);
    const accent = Color(0xFF00FF41);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(children: [
            Icon(Icons.auto_fix_high, color: accent, size: 12),
            const SizedBox(width: 6),
            Text(
              '3D TWIN ENGINE',
              style: TextStyle(
                color: accent,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              'V48.1',
              style: TextStyle(
                color: accent.withValues(alpha: 0.5),
                fontSize: 8,
                letterSpacing: 1,
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // Point Size quick slider
          Row(children: [
            Icon(Icons.radio_button_unchecked, color: accent, size: 10),
            const SizedBox(width: 4),
            Text('SIZE', style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                _sizeLabel(cfg.pointSize),
                style: TextStyle(color: accent, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: accent,
              inactiveTrackColor: accent.withValues(alpha: 0.15),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.12),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: SizedBox(
              height: 28,
              child: Slider(
                value: cfg.pointSize,
                min: 0.4,
                max: 2.2,
                onChanged: notifier.setPointSize,
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Cluster Density quick slider
          Row(children: [
            Icon(Icons.scatter_plot, color: const Color(0xFF00CCFF), size: 10),
            const SizedBox(width: 4),
            Text('DENSITY',
                style: const TextStyle(color: Color(0xFF00CCFF), fontSize: 9, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF00CCFF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${(cfg.clusterDensity * 100).round()}%',
                style: const TextStyle(color: Color(0xFF00CCFF), fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF00CCFF),
              inactiveTrackColor: const Color(0xFF00CCFF).withValues(alpha: 0.15),
              thumbColor: const Color(0xFF00CCFF),
              overlayColor: const Color(0xFF00CCFF).withValues(alpha: 0.12),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: SizedBox(
              height: 28,
              child: Slider(
                value: cfg.clusterDensity,
                min: 0.0,
                max: 1.0,
                onChanged: notifier.setClusterDensity,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Kalman + AI toggles row
          Row(children: [
            _MiniToggle('KALMAN', cfg.kalmanEnabled, accent, notifier.setKalman),
            const SizedBox(width: 4),
            _MiniToggle('AI FILL', cfg.aiInterpolation, const Color(0xFFFF00FF), notifier.setAiInterp),
            const SizedBox(width: 4),
            _MiniToggle('DBSCAN', cfg.useDBSCAN, const Color(0xFFFFD700), notifier.setUseDBSCAN),
          ]),
        ],
      ),
    );
  }

  String _sizeLabel(double v) {
    if (v < 0.7) return 'TINY';
    if (v < 0.9) return 'SMALL';
    if (v < 1.15) return 'MED';
    if (v < 1.6) return 'LARGE';
    return 'HUGE';
  }
}

class _MiniToggle extends StatelessWidget {
  final String label;
  final bool value;
  final Color color;
  final void Function(bool) onChanged;

  const _MiniToggle(this.label, this.value, this.color, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: value ? color.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(color: value ? color : Colors.white24),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: value ? color : Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Static helper to show the panel from anywhere
class FalconSidePanel {
  static void show(BuildContext context) =>
      _FalconSidePanelRoute.show(context);
}
