import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/core/config/theme/app_theme.dart';
import 'package:college_level/features/shared/settings/presentation/pages/licenses_page.dart';

/// Attribution has to be complete to be worth anything, so the grouping is what
/// these cover: one [LicenseEntry] may apply to several packages, and every
/// package that appears in the registry must appear on screen.
void main() {
  setUpAll(() {
    // Registry additions are global and cannot be undone, which is fine for one
    // file — but it is why these names are deliberately unlikely to collide.
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(
        ['zz_test_beta', 'zz_test_alpha'], // one notice, two packages
        'Shared BSD notice.',
      );
      yield const LicenseEntryWithLineBreaks(
        ['zz_test_alpha'],
        'A second notice for alpha only.',
      );
      yield const LicenseEntryWithLineBreaks(
        ['_zz_test_underscore'],
        'Underscore-prefixed package.',
      );
    });
  });

  // `AppTheme` rather than a bare MaterialApp: `context.scheme` reads the
  // `AppTokens` theme extension with a null assertion, so any widget in this app
  // requires a theme that carries it. Production always does.
  Widget host() => MaterialApp(
        theme: AppTheme.dark,
        home: const LicensesPage(),
      );

  testWidgets('lists every package the registry reports', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('zz_test_alpha'), findsOneWidget);
    expect(find.text('zz_test_beta'), findsOneWidget);
    expect(find.text('_zz_test_underscore'), findsOneWidget);
  });

  testWidgets('a shared notice is filed under each of its packages',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // alpha has the shared notice plus one of its own; beta has only the shared
    // one. Dropping either would understate the attribution.
    final alpha = find.ancestor(
      of: find.text('zz_test_alpha'),
      matching: find.byType(Column),
    );
    expect(
      find.descendant(of: alpha.first, matching: find.text('2 licences')),
      findsOneWidget,
    );
  });

  testWidgets('singular and plural are both correct', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Exactly one licence must not read "1 licences".
    expect(find.text('1 licence'), findsWidgets);
    expect(find.text('1 licences'), findsNothing);
  });

  testWidgets('sorts case-insensitively', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // A leading underscore must not bucket a package away from its alphabetical
    // neighbours — the built-in page lists `_fe_analyzer_shared` first for exactly
    // that reason, which reads like a glitch.
    final underscore = tester.getTopLeft(find.text('_zz_test_underscore')).dy;
    final alpha = tester.getTopLeft(find.text('zz_test_alpha')).dy;
    expect(
      underscore,
      greaterThan(alpha),
      reason: '_zz sorts under "z", not before "a"',
    );
  });

  testWidgets('opens a package to read its licence text', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('zz_test_beta'));
    await tester.pumpAndSettle();

    // The detail page shows the actual notice, not a placeholder.
    expect(find.text('Shared BSD notice.'), findsOneWidget);
    // And is titled with the package, so it is obvious what is being read.
    expect(find.text('zz_test_beta'), findsWidgets);
  });

}
