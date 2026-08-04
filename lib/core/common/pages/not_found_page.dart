import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_theme.dart';
import '../widgets/app_button.dart';

/// Port of `src/pages/not-found/index.tsx` — the branded 404 with a giant
/// gradient numeral and Home/Back actions.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Scaffold(
      body: Stack(
        children: [
          // The ambient violet glow behind the numeral.
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.22),
                    scheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [scheme.primary, scheme.chart[3]],
                    ).createShader(bounds),
                    child: Text(
                      '404',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 84,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Page not found', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    message ?? "The page you're looking for doesn't exist or has moved.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (context.canPop())
                        AppButton(
                          label: 'Go back',
                          variant: AppButtonVariant.outline,
                          icon: Icons.arrow_back_rounded,
                          onPressed: context.pop,
                        ),
                      if (context.canPop()) const SizedBox(width: 12),
                      AppButton(
                        label: 'Home',
                        icon: Icons.home_outlined,
                        onPressed: () => context.go('/'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
