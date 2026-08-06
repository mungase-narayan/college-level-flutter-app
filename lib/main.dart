import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/common/widgets/widgets.dart';
import 'core/config/injection_modules/service_locator.dart';
import 'core/design/platform/app_platform.dart';
import 'core/design/utils/glass_refraction.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Registers dependencies and restores the persisted session, so the router's
  // very first redirect already knows whether anyone is signed in.
  await initServiceLocator();

  // Compiled before the first frame so no glass surface paints an un-refracted
  // frame and then pops. Never throws, and is skipped entirely off iOS where the
  // glass layer is not used at all.
  if (AppPlatform.useGlass) {
    await GlassRefraction.load();
  }

  // Same reasoning as the shader above. The splash is alive for only the handful
  // of frames it takes the session to resolve — shorter than an asynchronous
  // asset decode — so without warming the cache first its logo slot lays out at
  // the right size but paints nothing, and the mark is never actually seen.
  await _precacheAppLogo();

  runApp(const CollegeLevelApp());
}

/// Decodes [SplashPage]'s logo into the image cache before the first frame.
///
/// Resolved against [ImageConfiguration.empty] deliberately: the asset has no
/// density variants, so this produces the same cache key `Image.asset` will look
/// up later. A decode failure is swallowed — a missing logo is not a reason to
/// block startup.
Future<void> _precacheAppLogo() async {
  final stream = const AssetImage(
    AppLogo.asset,
  ).resolve(ImageConfiguration.empty);
  final completer = Completer<void>();

  late final ImageStreamListener listener;
  void finish() {
    stream.removeListener(listener);
    if (!completer.isCompleted) completer.complete();
  }

  listener = ImageStreamListener(
    (_, _) => finish(),
    onError: (_, _) => finish(),
  );
  stream.addListener(listener);

  await completer.future;
}
