import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/core/utils/math_text.dart';

void main() {
  group('MathText.pretty', () {
    test('raises a simple exponent', () {
      expect(
        MathText.pretty('What is the codomain of the function f(x) = x^2?'),
        'What is the codomain of the function f(x) = x²?',
      );
    });

    test('raises a braced exponent, signs included', () {
      expect(MathText.pretty('10^{-3}'), '10⁻³');
      expect(MathText.pretty('2^{10}'), '2¹⁰');
    });

    test('lowers a subscript', () {
      expect(MathText.pretty('a_1 + a_2'), 'a₁ + a₂');
    });

    test('handles the algebraic n and i exponents', () {
      expect(MathText.pretty('x^n'), 'xⁿ');
      expect(MathText.pretty('z^i'), 'zⁱ');
    });

    /// Half-converting would read worse than leaving it written out.
    test('leaves an unmappable exponent untouched', () {
      expect(MathText.pretty(r'x^{a+b}'), r'x^{a+b}');
      expect(MathText.pretty('x^Q'), 'x^Q');
    });

    test('leaves ordinary prose alone', () {
      const plain = 'Topological sorting is defined only for which graph?';
      expect(MathText.pretty(plain), plain);
    });

    /// A dollar sign in a question is as likely to be money as TeX.
    test('does not touch dollar signs', () {
      expect(MathText.pretty(r'A shirt costs $20 and a hat costs $5.'),
          r'A shirt costs $20 and a hat costs $5.');
    });

    test('a stray caret cannot swallow the sentence', () {
      expect(MathText.pretty('Use the ^ symbol carefully'),
          'Use the ^ symbol carefully');
    });

    test('null and empty are safe', () {
      expect(MathText.pretty(null), '');
      expect(MathText.pretty(''), '');
    });

    test('converts several exponents in one string', () {
      expect(MathText.pretty('x^2 + y^2 = z^2'), 'x² + y² = z²');
    });
  });
}
