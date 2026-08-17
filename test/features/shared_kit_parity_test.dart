import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/core/common/pages/feature_pending_page.dart';
import 'package:college_level/core/common/widgets/widgets.dart';

import '../support/platform_parity.dart';

/// The pieces every filter sheet is built from, and the placeholder that stands
/// in for eleven sidebar destinations.
///
/// These are the highest-leverage parity checks in the app: a regression in
/// [AppOptionGroup] hits four screens at once, and the two branches implement
/// its row icon *separately* — glass through `LiquidGlassListTile.leadingIcon`,
/// Material through a tinted square written by hand.
void main() {
  group('AppOptionGroup', () {
    bothPlatforms('renders every option, its icon and the selected check',
        (tester, host) async {
      var picked = '';

      await tester.pumpWidget(
        host(
          Scaffold(
            body: AppOptionGroup<String>(
              header: 'Show',
              selected: 'all',
              onSelected: (value) => picked = value,
              options: const [
                AppOptionItem(
                  value: 'all',
                  label: 'All Scheduled',
                  icon: Icons.grid_view_rounded,
                ),
                AppOptionItem(
                  value: 'classes',
                  label: 'Classes',
                  icon: Icons.school_outlined,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show'), findsOneWidget);
      expect(find.text('All Scheduled'), findsOneWidget);
      expect(find.text('Classes'), findsOneWidget);

      // Both icons render on both branches — the divergence this guards.
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
      // Exactly one check, on the selected row.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.text('Classes'));
      expect(picked, 'classes');
    });

    bothPlatforms('an option without an icon still renders',
        (tester, host) async {
      await tester.pumpWidget(
        host(
          Scaffold(
            body: AppOptionGroup<int>(
              selected: 1,
              onSelected: (_) {},
              options: const [
                AppOptionItem(value: 1, label: 'One', description: 'first'),
                AppOptionItem(value: 2, label: 'Two'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('One'), findsOneWidget);
      expect(find.text('first'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
    });
  });

  group('AppFilterActions', () {
    bothPlatforms('offers Reset and Apply, with Reset disabled when idle',
        (tester, host) async {
      var applied = false;

      await tester.pumpWidget(
        host(
          Scaffold(
            body: AppFilterActions(
              onReset: null,
              onApply: () => applied = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      // Cancel was deliberately dropped — dismissing is a swipe away.
      expect(find.text('Cancel'), findsNothing);

      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(applied, isFalse, reason: 'a disabled Reset must do nothing');

      await tester.tap(find.text('Apply'));
      expect(applied, isTrue);
    });

    bothPlatforms('an enabled Reset fires', (tester, host) async {
      var reset = false;

      await tester.pumpWidget(
        host(
          Scaffold(
            body: AppFilterActions(
              onReset: () => reset = true,
              onApply: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset'));
      expect(reset, isTrue);
    });
  });

  group('FeaturePendingPage', () {
    // Eleven sidebar destinations render this one page — Analytics, Weekly
    // Report, Notes, Contests, Rating, Leaderboard, Badges, Wallet,
    // Announcements, Attendance and Academic Calendar.
    bothPlatforms('renders its title and description', (tester, host) async {
      await tester.pumpWidget(
        host(
          const FeaturePendingPage(
            title: 'Attendance',
            description: 'Coming in a later pass.',
            showAppBar: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Coming in a later pass.'), findsOneWidget);
    });
  });
}
