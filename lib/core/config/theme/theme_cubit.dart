import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / system, persisted across launches.
///
/// The port of `src/providers/theme-provider.tsx`, which stores the choice
/// under `localStorage['vite-ui-theme']` and **defaults to dark**
/// (`<ThemeProvider defaultTheme="dark">` in `App.tsx`).
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._prefs) : super(_read(_prefs));

  static const _key = 'vite-ui-theme';

  final SharedPreferences _prefs;

  static ThemeMode _read(SharedPreferences prefs) =>
      _decode(prefs.getString(_key)) ?? ThemeMode.dark;

  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    await _prefs.setString(_key, _encode(mode));
  }

  /// Flips between light and dark, resolving `system` against the current
  /// platform brightness first so the first tap always visibly changes things.
  Future<void> toggle(Brightness currentBrightness) {
    final isDark = state == ThemeMode.dark ||
        (state == ThemeMode.system && currentBrightness == Brightness.dark);
    return set(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode? _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
}
