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

    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCardHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            trailing: trailing,
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// The `icon · title / subtitle` header both section-card variants draw.
///
/// The icon and the trailing slot are boxed to the **title's** line height and
/// centred inside it, so they sit beside the heading. Left to a plain `Row`,
/// which centres on the tallest child, a two-line header drops the icon into
/// the gap between the title and the subtitle — pointing at neither.
class SectionCardHeader extends StatelessWidget {
  const SectionCardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.gap = 8,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final subtitle = this.subtitle;

    final titleStyle = theme.textTheme.titleSmall;
    // Derived from the style rather than hardcoded: a change to the type scale
    // would otherwise silently drift the icon off the heading again.
    final titleLine = (titleStyle?.fontSize ?? 15) * (titleStyle?.height ?? 1.4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          SizedBox(
            height: titleLine,
            child: Center(child: Icon(icon, size: 18, color: scheme.primary)),
          ),
          SizedBox(width: gap),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              if (subtitle != null)
                Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        // Top-aligned rather than boxed to the title line: a trailing chip has
        // its own padding and is usually taller than the line, so forcing it
        // into that box clips it. Starting at the same edge as the title reads
        // as aligned without constraining the child's height.
        ?trailing,
      ],
    );
  }
}
