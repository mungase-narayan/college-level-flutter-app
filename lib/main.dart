import 'package:flutter/material.dart';

import 'app.dart';
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

  runApp(const CollegeLevelApp());
}
