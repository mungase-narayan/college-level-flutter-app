/// Tolerant readers for JSON scalars.
///
/// The backend's column types do not map cleanly onto Dart's: Postgres sends
/// `numeric` columns as **strings** through the pg driver, while codes that
/// happen to be numeric — semester `3`, division `1` — arrive as **numbers**
/// even though they are display text. A plain `as String?` or `as num?` cast
/// therefore throws on ordinary, valid data, and because parsing happens inside
/// `RepositoryGuard` the whole screen collapses to "Something went wrong" with
/// no clue which field was at fault.
///
/// These read the value for what it is meant to be rather than what the wire
/// happened to carry. Use them in models instead of casting.
library;

/// The value as display text, or `''` when absent.
String asString(Object? value) => asStringOrNull(value) ?? '';

/// The value as display text, or null when absent.
String? asStringOrNull(Object? value) => switch (value) {
      String s => s,
      num n => n.toString(),
      bool b => b.toString(),
      _ => null,
    };

/// The value as a whole number, or `0` when absent or unparseable.
int asInt(Object? value) => asIntOrNull(value) ?? 0;

/// The value as a whole number, or null when absent or unparseable.
int? asIntOrNull(Object? value) => switch (value) {
      num n => n.toInt(),
      String s => int.tryParse(s) ?? double.tryParse(s)?.toInt(),
      _ => null,
    };

/// The value as a flag, accepting the `0`/`1` and `"true"` forms too.
bool asBool(Object? value, {bool orElse = false}) => switch (value) {
      bool b => b,
      num n => n != 0,
      String s => s.toLowerCase() == 'true' || s == '1',
      _ => orElse,
    };

/// The object rows of a JSON array, skipping anything that isn't one.
List<Map<String, dynamic>> asObjectList(Object? value) =>
    (value as List?)?.whereType<Map<String, dynamic>>().toList(growable: false) ??
    const [];

/// The string entries of a JSON array.
List<String> asStringList(Object? value) =>
    (value as List?)?.whereType<String>().toList(growable: false) ?? const [];

/// Parses a nested object with [parse], or null when the key is absent or is
/// not an object.
T? asObject<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    value is Map<String, dynamic> ? parse(value) : null;
