/// Username rules for `PATCH /users/me`.
///
/// A pure function rather than a method on the edit form, for two reasons: it is a
/// domain rule the backend also enforces, not presentation; and keeping it out of a
/// widget means it can be tested directly instead of by pumping a form and reading
/// an error string back out.
///
/// Ported verbatim from the web app's zod schema in
/// `settings/components/edit-profile-dialog.tsx`. If the two drift, the clients
/// give different errors for the same input and one of them contradicts the API.
abstract final class UsernameRules {
  static const minLength = 3;
  static const maxLength = 254;

  /// Letters, digits and `. _ @ + -`. An email address is therefore valid, which
  /// matters because a new account's username defaults to its email.
  static final allowed = RegExp(r'^[a-zA-Z0-9._@+-]+$');

  /// What actually gets sent: trimmed and lowercased, as the web app does.
  static String normalize(String raw) => raw.trim().toLowerCase();

  /// The error to show, or null when acceptable.
  ///
  /// Validates the *trimmed* value, so trailing whitespace never counts toward the
  /// length or trips the character check.
  static String? validate(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return 'Username is required';
    if (value.length < minLength) {
      return 'Username must be at least $minLength characters';
    }
    if (value.length > maxLength) {
      return 'Username must be $maxLength characters or fewer';
    }
    if (!allowed.hasMatch(value)) {
      return 'Only letters, numbers and . _ @ + - are allowed';
    }
    return null;
  }
}
