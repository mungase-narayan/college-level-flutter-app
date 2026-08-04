import 'dart:ui' as ui;
import 'dart:ui' show Size, TileMode;

import 'package:flutter/foundation.dart';

import '../theme/glass_specs.dart';

/// Builds the [ui.ImageFilter] that gives glass surfaces their lensing edge.
///
/// ### Why a shader is necessary
///
/// A `BackdropFilter` can only *blur* the backdrop. What separates iOS 26's Liquid
/// Glass from ordinary frosted glass is that it also **refracts**: content behind
/// the surface is displaced, stretched and partly inverted near the rim, and split
/// very slightly into its colour components. Neither is expressible as an
/// `ImageFilter.blur`, at any sigma.
///
/// So the blur and the displacement are composed into one filter —
/// `ImageFilter.compose(outer: refraction, inner: blur)` — and both run in the
/// single `BackdropFilter` pass the surface already paid for.
///
/// ### Availability
///
/// `ImageFilter.shader` throws [UnsupportedError] unless the app is running on
/// Impeller. iOS has used Impeller by default for several releases, so this is the
/// normal path there — but the failure is handled rather than assumed, and every
/// entry point degrades to a plain blur. A missing shader must never be able to
/// take the chrome down with it.
abstract final class GlassRefraction {
  static const _assetKey = 'shaders/liquid_glass_refraction.frag';

  /// Uniform slots. Indices 0 and 1 are the `vec2` size the engine fills in, so
  /// ours start at 2 — the order here must match the `uniform` declaration order
  /// in the `.frag` file exactly, because the mapping is positional and silent.
  static const _uRadius = 2;
  static const _uRefraction = 3;
  static const _uDispersion = 4;
  static const _uEdgeWidth = 5;

  static ui.FragmentProgram? _program;
  static bool _loadAttempted = false;

  /// True once the shader is compiled and usable.
  static bool get isAvailable => _program != null;

  /// Loads and caches the program. Call once during bootstrap, before the first
  /// frame, so no surface ever paints an un-refracted first frame and then pops.
  ///
  /// Never throws: a shader that fails to load leaves [isAvailable] false and every
  /// surface falls back to a plain blur.
  static Future<void> load() async {
    if (_loadAttempted) return;
    _loadAttempted = true;
    try {
      _program = await ui.FragmentProgram.fromAsset(_assetKey);
    } on Object catch (error, stack) {
      // Debug-only: on a non-Impeller target this is expected, not a defect.
      assert(() {
        debugPrint('GlassRefraction unavailable, falling back to blur: $error');
        debugPrintStack(stackTrace: stack, maxFrames: 4);
        return true;
      }());
      _program = null;
    }
  }

  /// A blur composed with edge refraction, or a plain blur when the shader is
  /// unavailable or the surface is too small for the lensing to read.
  ///
  /// [sigma] is the blur radius; [radius] the surface's corner radius; [size] its
  /// painted size. Returns null when [sigma] is zero and no refraction applies, so
  /// callers can skip creating a `BackdropFilter` altogether.
  static ui.ImageFilter? filter({
    required double sigma,
    required double radius,
    required Size size,
    double refraction = GlassMetrics.chromeRefraction,
    double dispersion = GlassMetrics.chromeDispersion,
    double edgeWidth = GlassMetrics.chromeRefractionEdge,
  }) {
    final blur = sigma > 0
        ? ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          )
        : null;

    final program = _program;
    if (program == null || size.isEmpty) return blur;

    // Below roughly twice the edge width there is no optically flat centre left,
    // so the whole surface would smear instead of showing a rim. Cheaper and more
    // honest to skip it.
    final shortestSide = size.shortestSide;
    if (shortestSide < edgeWidth * 2) return blur;

    try {
      final shader = program.fragmentShader()
        ..setFloat(_uRadius, radius)
        ..setFloat(_uRefraction, refraction)
        ..setFloat(_uDispersion, dispersion)
        // Never let the lensing reach past the surface's own half-height, or the
        // two rims overlap in the middle and cancel.
        ..setFloat(_uEdgeWidth, edgeWidth.clamp(1.0, shortestSide / 2));

      final refract = ui.ImageFilter.shader(shader);
      return blur == null
          ? refract
          // Blur first, then bend the blurred result: bending first and blurring
          // after would average the displacement away.
          : ui.ImageFilter.compose(outer: refract, inner: blur);
    } on Object catch (error) {
      assert(() {
        debugPrint('GlassRefraction filter failed, using blur: $error');
        return true;
      }());
      // One failure means this platform cannot do it at all; stop retrying every
      // frame.
      _program = null;
      return blur;
    }
  }
}
