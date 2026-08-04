import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../../design/extensions/glass_context.dart';
import '../../design/widgets/liquid_glass_card.dart';

/// The standard surface used everywhere in the React app:
/// `rounded-2xl border border-border/60 bg-card p-4`.
///
/// This is the single highest-leverage widget in the app — every screen's content
/// sits on it — so it is where the iOS design layer plugs in. On iOS it renders
/// [LiquidGlassCard]; everywhere else it renders the original Material tree,
/// unchanged.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    if (context.useGlass) {
      return LiquidGlassCard(
        padding: padding,
        onTap: onTap,
        margin: margin,
        color: color,
        borderColor: borderColor,
        child: child,
      );
    }

    final scheme = context.scheme;
    final radius = BorderRadius.circular(AppTheme.radiusLg);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: color ?? scheme.card,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: borderColor ?? scheme.border.withValues(alpha: 0.6),
              ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A card with a title row and optional trailing action — the shape most
/// dashboard panels take.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.icon,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (context.useGlass) {
      return LiquidGlassSectionCard(
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        icon: icon,
        padding: padding,
        child: child,
      );
    }

    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    if (subtitle != null)
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
