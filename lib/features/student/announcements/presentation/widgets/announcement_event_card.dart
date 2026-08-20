import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/announcement.dart';

/// The four event facts, with the registration bar beneath them.
///
/// Only ever built for an EVENT — the web gates the whole card the same way, so
/// a general announcement never shows a venue or a fee.
class AnnouncementEventCard extends StatelessWidget {
  const AnnouncementEventCard({
    super.key,
    required this.announcement,
    required this.action,
  });

  final AnnouncementDetail announcement;

  /// The registration bar. Built by the page, which owns the busy state.
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.calendar_month_outlined,
                  shade: TwColors.violet,
                  label: 'When',
                  value: announcement.dateRange,
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.place_outlined,
                  shade: TwColors.blue,
                  label: 'Venue',
                  value: announcement.venue,
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.payments_outlined,
                  shade: TwColors.emerald,
                  label: 'Fees',
                  value: announcement.feeLabel,
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.group_outlined,
                  shade: TwColors.amber,
                  label: 'Registered',
                  value: announcement.registeredLabel,
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.muted.withValues(alpha: 0.4),
              border: Border(
                top: BorderSide(color: scheme.border.withValues(alpha: 0.6)),
              ),
            ),
            child: action,
          ),
        ],
      ),
    );
  }
}

/// A tinted icon chip, an uppercase label, and a value.
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.shade,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final TwShade shade;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.tokens.tone(shade);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(icon, size: 18, color: tone.foreground),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
