/// Renders the caret/underscore exponent notation that question text is
/// authored in — `x^2`, `10^{-3}`, `a_1` — as real Unicode super- and
/// subscripts.
///
/// Unicode rather than the `<sup>` builder the markdown pipeline uses: this runs
/// inside compact list rows, and staying a plain [String] keeps `maxLines` and
/// ellipsis behaving exactly as they do for ordinary prose. A `WidgetSpan` would
/// break both.
///
/// Deliberately does **not** touch `$…$`. A title is free-form text where a
/// dollar sign is as likely to be currency as a TeX delimiter, and silently
/// eating one would be worse than leaving `x^2` alone. Text with real TeX
/// belongs in `AppMarkdown`, which renders it through KaTeX.
class MathText {
  const MathText._();

  static const _superscripts = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
    '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
    'n': 'ⁿ', 'i': 'ⁱ',
  };

  static const _subscripts = {
    '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
    '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
    '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
  };

  /// `^` or `_`, then either a braced group or a short run of exponent-ish
  /// characters. Bounded so a stray caret in prose cannot swallow a sentence.
  static final _pattern = RegExp(r'([\^_])(\{([^}]{1,16})\}|[A-Za-z0-9+\-=]{1,4})');

  /// Returns [text] with exponents raised and indices lowered.
  ///
  /// Any run containing a character with no Unicode equivalent is left exactly
  /// as written — a half-converted `x^(a⁺b)` reads worse than the original.
  static String pretty(String? text) {
    final source = text ?? '';
    if (!source.contains('^') && !source.contains('_')) return source;

    return source.replaceAllMapped(_pattern, (match) {
      final isSuper = match.group(1) == '^';
      final body = match.group(3) ?? match.group(2)!;
      final table = isSuper ? _superscripts : _subscripts;

      final buffer = StringBuffer();
      for (final char in body.split('')) {
        final mapped = table[char];
        if (mapped == null) return match.group(0)!;
        buffer.write(mapped);
      }
      return buffer.toString();
    });
  }
}
