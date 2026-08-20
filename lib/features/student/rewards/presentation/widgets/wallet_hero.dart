import 'package:flutter/material.dart';

import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/rewards.dart';

/// The wallet's identity: a very large gradient balance over a soft glow.
///
/// Sits above the tabs and outside every loading and error branch, as it does
/// on the web — during the first fetch it shows an em dash rather than
/// vanishing, so the screen never collapses to a bare tab bar.
class WalletHero extends StatelessWidget {
  const WalletHero({super.key, this.wallet, this.isLoading = false});

  final Wallet? wallet;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final balance = wallet?.balance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        children: [
          Text(
            'MY REWARDS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your Rewards Wallet',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Stack(
            alignment: Alignment.center,
            children: [
              // The web's `blur-[110px]` halo. A wide, soft BoxShadow renders
              // the same way on both platform branches and costs far less than
              // a BackdropFilter.
              Container(
                width: 180,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.18),
                      blurRadius: 90,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          scheme.primary.withValues(alpha: 0.70),
                        ],
                      ).createShader(bounds),
                      child: Text(
                        // Never `0` while the first fetch is in flight — a zero
                        // balance and an unknown one are different claims.
                        isLoading || balance == null ? '—' : '$balance',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: 64,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          // ShaderMask paints through the glyphs, so the colour
                          // only has to be opaque.
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'points',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Earn points every day you log in, complete daily challenges, and '
            'finish a perfect month — then spend them in the store.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppTheme.radiusSm),
        ],
      ),
    );
  }
}
