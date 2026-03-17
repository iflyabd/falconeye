import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'falcon_side_panel.dart';
import '../theme.dart';

/// Back button + index button shown top-left on all pushed pages
class BackButtonTopLeft extends StatelessWidget {
  final EdgeInsets padding;
  final Color? backgroundColor;
  final Color? iconColor;

  const BackButtonTopLeft({
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = GoRouter.of(context).canPop() || Navigator.canPop(context);
    final bg = backgroundColor ?? Colors.black.withValues(alpha: 0.85);
    final ic = iconColor ?? theme.colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: padding,
        child: Align(
          alignment: Alignment.topLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Back button
              if (canPop)
                _NavBtn(
                  icon: Icons.arrow_back,
                  color: ic,
                  bg: bg,
                  onTap: () => context.pop(),
                  tooltip: 'Back',
                ),
              if (canPop) const SizedBox(width: 6),
              // Index button — always visible
              _NavBtn(
                icon: Icons.apps,
                color: ic,
                bg: bg,
                onTap: () => context.go('/master_control'),
                tooltip: 'All Pages',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  final String tooltip;

  const _NavBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}
