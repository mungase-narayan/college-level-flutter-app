import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Shown while the persisted session is read out of secure storage at boot.
///
/// The router's redirect blocks on `AuthStatus.unknown`, so this is what the
/// user sees for the handful of frames before the session resolves.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The launcher artwork itself, so the splash reads as a
            // continuation of the icon the user just tapped.
            const AppLogo(size: 62, radius: AppTheme.radiusLg),
            const SizedBox(height: 22),
            Text('College Level', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
