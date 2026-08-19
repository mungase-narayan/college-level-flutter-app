import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/rewards.dart';

/// One item in the rewards store.
///
/// Affordability is decided here rather than by the caller so the price and the
/// button state can never disagree.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.balance,
    required this.onRedeem,
  });

  final Product product;
  final int balance;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final canAfford = balance >= product.price;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _Thumbnail(product: product),
                ),
              ),
              if (product.isTicket)
                Positioned(
                  top: 10,
                  left: 10,
                  // Marks the item as taking effect in the app rather than
                  // being handed over by the school.
                  child: AppBadge(
                    'Effect',
                    shade: TwColors.violet,
                    dense: true,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (product.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    product.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      AppIcons.coins,
                      size: 15,
                      color: tokens.warning.foreground,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${product.price}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: tokens.warning.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    AppButton(
                      label: canAfford ? 'Redeem' : 'Not enough',
                      size: AppButtonSize.sm,
                      // A null callback is what disables the button on both
                      // the Material and glass branches.
                      onPressed: canAfford ? onRedeem : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final url = product.imageUrl;

    final placeholder = Container(
      color: scheme.muted,
      alignment: Alignment.center,
      child: Icon(
        product.isTicket ? Icons.hourglass_bottom_rounded : Icons.redeem_rounded,
        size: 38,
        color: scheme.mutedForeground.withValues(alpha: 0.55),
      ),
    );

    if (url == null) return placeholder;

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => const AppSkeleton(height: double.infinity),
      // A broken or expired image URL must still leave a usable card.
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
