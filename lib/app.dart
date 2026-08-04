import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/config/injection_modules/service_locator.dart';
import 'core/config/router/app_router.dart';
import 'core/config/theme/app_theme.dart';
import 'core/config/theme/reduce_transparency_cubit.dart';
import 'core/config/theme/theme_cubit.dart';
import 'core/design/animations/glass_curves.dart';
import 'core/design/platform/app_platform.dart';
import 'core/design/platform/glass_scope.dart';
import 'core/design/theme/liquid_glass_theme.dart';
import 'core/design/widgets/glass_backdrop.dart';
import 'features/auth/presentation/bloc/auth/auth_bloc.dart';

/// The provider tree, mirroring the order in `src/App.tsx`:
/// ThemeProvider → Toaster → redux Provider → PersistGate → QueryClientProvider
/// → AppRoutes.
///
/// Here `PersistGate` is replaced by the [AuthCheckRequested] dispatched below,
/// and react-query by each feature's cubit.
class CollegeLevelApp extends StatefulWidget {
  const CollegeLevelApp({super.key});

  @override
  State<CollegeLevelApp> createState() => _CollegeLevelAppState();
}

class _CollegeLevelAppState extends State<CollegeLevelApp> {
  late final AuthBloc _authBloc = sl<AuthBloc>()..add(const AuthCheckRequested());
  late final GoRouter _router = createRouter(_authBloc);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The one platform decision in the app. On iOS the theme carries the Liquid
    // Glass materials and the `builder` below mounts the glass scope; everywhere
    // else this is false and the tree is exactly what it was before the design
    // layer existed.
    final useGlass = AppPlatform.useGlass;

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _authBloc),
        BlocProvider<ThemeCubit>(create: (_) => sl<ThemeCubit>()),
        BlocProvider<ReduceTransparencyCubit>(
          create: (_) => sl<ReduceTransparencyCubit>(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) => MaterialApp.router(
          title: 'College Level',
          debugShowCheckedModeBanner: false,
          theme: useGlass ? LiquidGlassTheme.light : AppTheme.light,
          darkTheme: useGlass ? LiquidGlassTheme.dark : AppTheme.dark,
          // The web app ships `defaultTheme="dark"`; ThemeCubit defaults to
          // ThemeMode.dark to match.
          themeMode: themeMode,
          // Glass is a continuous material, so a light↔dark switch cross-fades
          // the translucency instead of cutting between two looks.
          themeAnimationDuration:
              useGlass ? GlassDurations.theme : kThemeAnimationDuration,
          themeAnimationCurve:
              useGlass ? GlassCurves.easeOutSmooth : Curves.linear,
          routerConfig: _router,
          builder: useGlass ? _buildGlassLayer : null,
        ),
      ),
    );
  }

  /// Mounts the two things every glass widget below depends on.
  ///
  /// This runs *inside* [MaterialApp] but *above* the router's navigator, which
  /// is the only place both are possible: [GlassScope] needs the resolved
  /// [Theme] and [MediaQuery] to exist, and [GlassBackdrop] must sit behind
  /// every route — including full-screen drill-downs pushed on the root
  /// navigator — rather than inside any one of them.
  ///
  /// `MaterialApp.builder` was previously unused, so nothing is displaced.
  Widget _buildGlassLayer(BuildContext context, Widget? child) {
    return BlocBuilder<ReduceTransparencyCubit, bool>(
      builder: (context, reduceTransparency) => GlassScope(
        reduceTransparency: reduceTransparency,
        // Every Scaffold is transparent under `LiquidGlassTheme`, so this
        // ambient gradient is what the floating chrome's blur samples.
        child: GlassBackdrop(child: child),
      ),
    );
  }
}
