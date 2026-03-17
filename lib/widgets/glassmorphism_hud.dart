// =============================================================================
// FALCON EYE V48.1 SOVEREIGN — GLASSMORPHISM HUD WIDGETS
// Full Tactical Glassmorphism design language:
//   - Frosted glass panels (BackdropFilter sigma:12)
//   - Semi-transparent bg (Colors.black @ 0.35 alpha)
//   - Neon Cyan #00E5FF primary, Matrix Green #00FF41 secondary
//   - BoxShadow glow (blurRadius:20, spreadRadius:2)
//   - Pulsing neon borders, animated scan lines
//   - Floating pill buttons, slide-in glass drawers
// =============================================================================
import 'dart:ui';
import 'package:flutter/material.dart';

// ─── V47 Sovereign Accent Colors ──────────────────────────────────────────────
class SovereignColors {
  static const cyan = Color(0xFF00E5FF);
  static const matrixGreen = Color(0xFF00FF41);
  static const neonPink = Color(0xFFFF006E);
  static const neonAmber = Color(0xFFFFAA00);
  static const deepVoid = Color(0xFF000000);
  static const glassBg = Color(0x59000000); // 0.35 alpha
  static const glassLight = Color(0x1AFFFFFF); // 0.1 white overlay
}

/// Core glassmorphism panel — frosted blur with neon border and optional glow.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;
  final double opacity;
  final BorderRadius? borderRadius;
  final bool neonGlow;
  final Gradient? gradient;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderColor,
    this.borderWidth = 0.5,
    this.blurSigma = 12.0,
    this.opacity = 0.35,
    this.borderRadius,
    this.neonGlow = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final color = borderColor ?? Theme.of(context).colorScheme.primary;
    final radius = borderRadius ?? BorderRadius.circular(8);
    return Container(
      margin: margin,
      decoration: neonGlow
          ? BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding ?? const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.black.withValues(alpha: opacity),
                    ],
                  ),
              borderRadius: radius,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Glassmorphism pill button with neon glow on active state.
class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isActive;
  final double fontSize;
  final bool pill;

  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.onTap,
    this.isActive = false,
    this.fontSize = 9,
    this.pill = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderR = pill ? BorderRadius.circular(20) : BorderRadius.circular(6);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: borderR,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: pill ? 14 : 10,
              vertical: pill ? 8 : 6,
            ),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.25),
                        color.withValues(alpha: 0.1),
                      ],
                    )
                  : null,
              color: isActive ? null : Colors.black.withValues(alpha: 0.35),
              borderRadius: borderR,
              border: Border.all(
                color: isActive ? color : color.withValues(alpha: 0.3),
                width: isActive ? 1.0 : 0.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: color, size: 14),
                  if (label.isNotEmpty) const SizedBox(width: 5),
                ],
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      shadows: isActive
                          ? [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Neon-glow stat readout with pulsing animation for HUD displays.
class NeonStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool glow;
  final bool pulse;

  const NeonStat({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.glow = false,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.5),
            fontSize: 7,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            shadows: glow
                ? [
                    Shadow(color: color.withValues(alpha: 0.7), blurRadius: 10),
                    Shadow(color: color.withValues(alpha: 0.3), blurRadius: 20),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}

/// Glassmorphic top HUD bar with version badge and neon glow title.
class GlassHudBar extends StatelessWidget {
  final Color color;
  final String title;
  final String version;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const GlassHudBar({
    super.key,
    required this.color,
    this.title = 'FALCON EYE',
    this.version = 'V48.1 SOVEREIGN',
    this.actions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.65),
                Colors.black.withValues(alpha: 0.05),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: color.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              if (onBack != null) ...[
                GlassButton(
                  label: '',
                  icon: Icons.arrow_back,
                  color: color,
                  onTap: onBack,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(color: color.withValues(alpha: 0.5), blurRadius: 14),
                    Shadow(color: color.withValues(alpha: 0.2), blurRadius: 28),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // V47 Sovereign badge with double border
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  version,
                  style: TextStyle(
                    color: color,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated neon pulse border for active elements.
class NeonPulseBorder extends StatefulWidget {
  final Widget child;
  final Color color;
  final double borderRadius;

  const NeonPulseBorder({
    super.key,
    required this.child,
    required this.color,
    this.borderRadius = 8,
  });

  @override
  State<NeonPulseBorder> createState() => _NeonPulseBorderState();
}

class _NeonPulseBorderState extends State<NeonPulseBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.3 + 0.7 * _controller.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.18 * pulse),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: 0.06 * pulse),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
            border: Border.all(
              color: widget.color.withValues(alpha: 0.3 + 0.4 * pulse),
              width: 1,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Glassmorphic frosted bottom control strip with floating pill layout.
class GlassBottomStrip extends StatelessWidget {
  final List<Widget> children;
  final Color color;

  const GlassBottomStrip({
    super.key,
    required this.children,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.65),
                Colors.black.withValues(alpha: 0.05),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: color.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(children: children),
        ),
      ),
    );
  }
}

/// Corner brackets overlay for tactical HUD feel.
class CornerBrackets extends StatelessWidget {
  final Color color;
  final double size;
  final double strokeWidth;

  const CornerBrackets({
    super.key,
    required this.color,
    this.size = 24,
    this.strokeWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerBracketPainter(color: color, s: size, sw: strokeWidth),
      child: const SizedBox.expand(),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double s;
  final double sw;
  _CornerBracketPainter({required this.color, required this.s, required this.sw});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    const m = 6.0;
    // Top-left
    canvas.drawLine(Offset(m, m), Offset(m + s, m), p);
    canvas.drawLine(Offset(m, m), Offset(m, m + s), p);
    // Top-right
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m - s, m), p);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m, m + s), p);
    // Bottom-left
    canvas.drawLine(Offset(m, size.height - m), Offset(m + s, size.height - m), p);
    canvas.drawLine(Offset(m, size.height - m), Offset(m, size.height - m - s), p);
    // Bottom-right
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m - s, size.height - m), p);
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m, size.height - m - s), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// V47: Glassmorphic full-screen overlay with animated icon grid (for mode selector).
class GlassOverlay extends StatelessWidget {
  final Widget child;
  final Color color;
  final VoidCallback? onClose;
  final String title;

  const GlassOverlay({
    super.key,
    required this.child,
    required this.color,
    this.onClose,
    this.title = '',
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: Colors.black.withValues(alpha: 0.8),
          child: SafeArea(
            child: Column(
              children: [
                if (title.isNotEmpty || onClose != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                    child: Row(
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: TextStyle(
                              color: color,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(color: color.withValues(alpha: 0.4), blurRadius: 10),
                              ],
                            ),
                          ),
                        const Spacer(),
                        if (onClose != null)
                          GlassButton(
                            label: '',
                            icon: Icons.close,
                            color: color,
                            onTap: onClose,
                          ),
                      ],
                    ),
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// V47: Animated scan line effect for HUD backgrounds.
class HudScanLine extends StatefulWidget {
  final Color color;
  const HudScanLine({super.key, required this.color});

  @override
  State<HudScanLine> createState() => _HudScanLineState();
}

class _HudScanLineState extends State<HudScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ScanLinePainter(
            progress: _controller.value,
            color: widget.color,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;
  _ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle horizontal lines
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.015)
      ..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    // Moving scan beam
    final beamY = progress * size.height;
    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, beamY - 20, size.width, 40));
    canvas.drawRect(
      Rect.fromLTWH(0, beamY - 20, size.width, 40),
      beamPaint,
    );
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}

/// V47: Floating glass status pill for inline status display.
class GlassStatusPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final bool active;

  const GlassStatusPill({
    super.key,
    required this.text,
    this.icon,
    required this.color,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? color.withValues(alpha: 0.5) : color.withValues(alpha: 0.2),
              width: 0.5,
            ),
            boxShadow: active
                ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 10)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 12),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
