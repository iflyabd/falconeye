import 'package:flutter/material.dart';
import '../services/features_provider.dart' show FalconTheme;

/// Vision Mode Enum — 10 cinematic radio-wave visualization modes
/// Each mode carries its paired FalconTheme so one tap sets both together.
enum VisionMode {
  neoMatrix(
    name: 'Neo Matrix',
    description: 'Green vertical code rain with holographic figures',
    icon: Icons.code,
    primaryColor: Color(0xFF00FF41),
    secondaryColor: Color(0xFF003311),
    requiresRoot: false,
    effectIntensity: 1.0,
    linkedTheme: FalconTheme.neoGreen,
  ),
  darkKnight(
    name: 'Dark Knight',
    description: 'Dark blue holographic figures in smoke atmosphere',
    icon: Icons.visibility,
    primaryColor: Color(0xFF0099FF),
    secondaryColor: Color(0xFF001122),
    requiresRoot: false,
    effectIntensity: 0.8,
    linkedTheme: FalconTheme.darkKnightBlue,
  ),
  daredevil(
    name: 'Daredevil',
    description: 'Heavy rain particles with glowing blue energy aura',
    icon: Icons.blur_on,
    primaryColor: Color(0xFF00CCFF),
    secondaryColor: Color(0xFF002244),
    requiresRoot: false,
    effectIntensity: 1.2,
    linkedTheme: FalconTheme.daredevilCyan,
  ),
  lucy(
    name: 'Lucy',
    description: 'Vertical colorful data rain with energy aura',
    icon: Icons.auto_awesome,
    primaryColor: Color(0xFFFF00FF),
    secondaryColor: Color(0xFF4400AA),
    requiresRoot: false,
    effectIntensity: 1.5,
    linkedTheme: FalconTheme.lucyPsychedelic,
  ),
  matrix(
    name: 'Matrix',
    description: 'Classic green code rain with digital artifacts',
    icon: Icons.grid_on,
    primaryColor: Color(0xFF00FF00),
    secondaryColor: Color(0xFF002200),
    requiresRoot: false,
    effectIntensity: 1.0,
    linkedTheme: FalconTheme.militaryOlive,
  ),
  ironMan(
    name: 'Iron Man',
    description: 'Metallic HUD with red targeting reticles',
    icon: Icons.gps_fixed,
    primaryColor: Color(0xFFFF3333),
    secondaryColor: Color(0xFF660000),
    requiresRoot: false,
    effectIntensity: 1.0,
    linkedTheme: FalconTheme.ironManRed,
  ),
  eagleVision(
    name: 'Eagle Vision',
    description: 'AC white neon — threats red, allies blue, loot gold',
    icon: Icons.remove_red_eye,
    primaryColor: Color(0xFFE8F0FF),
    secondaryColor: Color(0xFF06061A),
    requiresRoot: false,
    effectIntensity: 1.3,
    linkedTheme: FalconTheme.eagleVision,
  ),
  subsurfaceVein(
    name: 'Subsurface Vein',
    description: 'Layered voxel soil with glowing mineral veins',
    icon: Icons.layers,
    primaryColor: Color(0xFFFFD700),
    secondaryColor: Color(0xFF442200),
    requiresRoot: true,
    effectIntensity: 0.9,
    linkedTheme: FalconTheme.goldVein,
  ),
  bioTransparency(
    name: 'Bio-Transparency',
    description: 'Transparent body with pulsing blood/neural flows',
    icon: Icons.favorite,
    primaryColor: Color(0xFFFF0066),
    secondaryColor: Color(0xFF330011),
    requiresRoot: true,
    effectIntensity: 1.1,
    linkedTheme: FalconTheme.bioRed,
  ),
  fusionTactical(
    name: 'Fusion Tactical',
    description: 'All modes layered with toggleable overlays',
    icon: Icons.dashboard,
    primaryColor: Color(0xFF00FFFF),
    secondaryColor: Color(0xFF003344),
    requiresRoot: true,
    effectIntensity: 2.0,
    linkedTheme: FalconTheme.fusionCyan,
  );

  const VisionMode({
    required this.name,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.requiresRoot,
    required this.effectIntensity,
    required this.linkedTheme,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final bool requiresRoot;
  final double effectIntensity;
  /// The FalconTheme that pairs with this mode — set together in one tap.
  final FalconTheme linkedTheme;
}
