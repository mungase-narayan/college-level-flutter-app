import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's "Reduce transparency" preference, persisted across launches.
///
/// Deliberately an in-app setting rather than a system read: Flutter exposes no
/// binding for iOS's `UIAccessibilityIsReduceTransparencyEnabled`. The closest
/// available signal is [MediaQueryData.highContrast] (which maps from
/// *Darker System Colors*, a different toggle), and `GlassScope` does honour it —
/// but relying on it alone would leave anyone who finds the frosted surfaces hard
/// to read with no way to turn them off. This gives them one.
///
/// Shaped to match [ThemeCubit] exactly — same storage mechanism, same
/// light-touch API — so the two read identically on the Settings screen.
class ReduceTransparencyCubit extends Cubit<bool> {
  ReduceTransparencyCubit(this._prefs) : super(_read(_prefs));

  static const _key = 'a11y-reduce-transparency';

  final SharedPreferences _prefs;

  static bool _read(SharedPreferences prefs) => prefs.getBool(_key) ?? false;

  Future<void> set(bool value) async {
    if (value == state) return;
    emit(value);
    await _prefs.setBool(_key, value);
  }

  Future<void> toggle() => set(!state);
}
