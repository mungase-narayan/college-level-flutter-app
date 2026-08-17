import 'package:intl/intl.dart';

/// Direct ports of the date/duration helpers in
/// `college-level-frontend/src/lib/utils.ts`, so dates read identically in both
/// clients (day-first, 12-hour clock).
class Fmt {
  const Fmt._();

  /// ISO date (`YYYY-MM-DD`, optionally with time) → `dd/mm/yyyy`.
  ///
  /// String-sliced rather than parsed, exactly as the React version is, so a
  /// `date`-typed column like `sessionDate` is never shifted by a timezone.
  static String dmy(String? iso) {
    if (iso == null || iso.length < 10) return '—';
    return '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';
  }

  /// ISO date → `02 Aug 2026`.
  ///
  /// Sliced rather than parsed for the same reason as [dmy], and two-digit on
  /// the day to match the web's `day: '2-digit'` — [longDate] would render the
  /// same date as `2 Aug 2026`.
  static String dmyLong(String? iso) {
    if (iso == null || iso.length < 10) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = int.tryParse(iso.substring(5, 7));
    if (month == null || month < 1 || month > 12) return '—';
    return '${iso.substring(8, 10)} ${months[month - 1]} ${iso.substring(0, 4)}';
  }

  /// Compact `dd/mm` — for dense chart axes.
  static String dm(String? iso) {
    if (iso == null || iso.length < 10) return '—';
    return '${iso.substring(8, 10)}/${iso.substring(5, 7)}';
  }

  /// `7 Jul 2026, 1:00 PM`. Returns `—` for unparseable input.
  static String dateTime(String? iso) {
    final date = parse(iso);
    if (date == null) return '—';
    return '${DateFormat('d MMM yyyy').format(date)}, '
        '${DateFormat('h:mm a').format(date)}';
  }

  /// `7 Jul 2026`.
  static String longDate(String? iso) {
    final date = parse(iso);
    if (date == null) return '—';
    return DateFormat('d MMM yyyy').format(date);
  }

  /// `1:00 PM`.
  static String time(String? iso) {
    final date = parse(iso);
    if (date == null) return '—';
    return DateFormat('h:mm a').format(date);
  }

  /// Human-friendly duration from seconds: `0s`, `45s`, `1m 30s`, `1h 2m`.
  static String duration(num? totalSeconds) {
    if (totalSeconds == null || totalSeconds.isNaN || totalSeconds <= 0) return '0s';
    final total = totalSeconds.floor();
    final s = total % 60;
    final m = (total ~/ 60) % 60;
    final h = total ~/ 3600;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  /// `mm:ss` / `hh:mm:ss` — the exam and contest countdown format.
  static String countdown(Duration remaining) {
    if (remaining.isNegative) remaining = Duration.zero;
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
  }

  /// Relative time for feeds and comments: `just now`, `5m ago`, `3h ago`,
  /// `2d ago`, then an absolute date beyond a week.
  static String relative(String? iso) {
    final date = parse(iso);
    if (date == null) return '—';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return longDate(iso);
  }

  /// `August 2026` — the heading over a month grid.
  static String monthYear(DateTime date) => DateFormat('MMMM yyyy').format(date);

  /// The `YYYY-MM-DD` key the daily-challenge endpoints expect.
  static String isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// The `YYYY-MM` key `GET /practice/daily-challenge/calendar` expects.
  static String isoMonth(DateTime date) => DateFormat('yyyy-MM').format(date);

  /// `Mar` — the abbreviated month, for the activity heatmap's axis labels.
  static String monthShort(DateTime date) => DateFormat('MMM').format(date);

  /// Parses an API timestamp into local time. Returns null when absent or
  /// malformed rather than throwing.
  static DateTime? parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso)?.toLocal();
  }

  /// `1,234` — thousands-separated integer.
  static String number(num? value) =>
      value == null ? '—' : NumberFormat.decimalPattern().format(value);

  /// `87%` from a 0–100 value.
  static String percent(num? value, {int decimals = 0}) =>
      value == null ? '—' : '${value.toStringAsFixed(decimals)}%';

  /// Initials for avatar fallbacks: `Ada Lovelace` → `AL`.
  static String initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
