import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/features/auth/domain/username_rules.dart';

/// Ported verbatim from the web app's zod schema. Drift here means the two clients
/// disagree about what the API accepts.
void main() {
  group('UsernameRules.validate', () {
    test('requires a value', () {
      expect(UsernameRules.validate(null), 'Username is required');
      expect(UsernameRules.validate(''), 'Username is required');
      // Whitespace only — trimmed first, so this is empty, not a 3-char name.
      expect(UsernameRules.validate('   '), 'Username is required');
    });

    test('enforces the minimum length on the trimmed value', () {
      expect(UsernameRules.validate('ab'),
          'Username must be at least 3 characters');
      expect(UsernameRules.validate('  ab  '),
          'Username must be at least 3 characters');
      expect(UsernameRules.validate('abc'), isNull);
    });

    test('enforces the maximum length', () {
      expect(UsernameRules.validate('a' * 254), isNull);
      expect(UsernameRules.validate('a' * 255),
          'Username must be 254 characters or fewer');
    });

    test('rejects characters the backend does not allow', () {
      for (final bad in [
        'has space',
        'slash/es',
        'hash#tag',
        'paren(s)',
        'quote"d',
        'semi;colon',
        'emoji🎉',
      ]) {
        expect(
          UsernameRules.validate(bad),
          'Only letters, numbers and . _ @ + - are allowed',
          reason: bad,
        );
      }
    });

    test('accepts the allowed punctuation, including a full email', () {
      for (final good in [
        'abc',
        'narayan.mungase1',
        // Usernames default to the email address, so this must pass.
        'narayan.mungase@mitcorer.edu.in',
        'a_b-c+d.e',
        'ABC123',
      ]) {
        expect(UsernameRules.validate(good), isNull, reason: good);
      }
    });
  });

  group('UsernameRules.normalize', () {
    test('trims and lowercases, matching what the web app sends', () {
      expect(UsernameRules.normalize('  Narayan.Mungase  '),
          'narayan.mungase');
      expect(UsernameRules.normalize('ABC'), 'abc');
    });

    test('a normalized value always passes validation', () {
      // Otherwise the form could accept input and then submit something invalid.
      for (final raw in ['  ABC  ', 'Narayan.Mungase@MITCORER.edu.in']) {
        expect(UsernameRules.validate(UsernameRules.normalize(raw)), isNull,
            reason: raw);
      }
    });

    test('normalizing is idempotent', () {
      const raw = '  Mixed.Case  ';
      final once = UsernameRules.normalize(raw);
      expect(UsernameRules.normalize(once), once);
    });
  });
}
