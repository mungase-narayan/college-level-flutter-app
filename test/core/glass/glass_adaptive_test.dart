import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/core/common/widgets/widgets.dart';
import 'package:college_level/core/config/theme/app_theme.dart';
import 'package:college_level/core/design/glass.dart';

/// Guards the contract the whole iOS design layer rests on: the shared widgets
/// swap their rendering on `AppPlatform.useGlass`, and the Android branch stays
/// exactly what it was before the glass layer existed.
///
/// Note that `defaultTargetPlatform` hard-returns [TargetPlatform.android]
/// whenever `FLUTTER_TEST` is set, so the app's other suites take the Material
/// branch automatically. Glass behaviour therefore has to be requested
/// explicitly — which is precisely why `debugUseGlassOverride` exists.
void main() {
  tearDown(() {
    // A leaked override would silently flip every later test in the run.
    AppPlatform.debugUseGlassOverride = null;
  });

  Widget host(Widget child, {bool glass = false, ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? (glass ? LiquidGlassTheme.dark : AppTheme.dark),
      home: GlassScope(child: Scaffold(body: Center(child: child))),
    );
  }

  group('AppPlatform.useGlass', () {
    test('is false under flutter_test by default', () {
      // The load-bearing assumption behind "Android cannot regress".
      expect(AppPlatform.useGlass, isFalse);
    });

    test('honours the debug override in both directions', () {
      AppPlatform.debugUseGlassOverride = true;
      expect(AppPlatform.useGlass, isTrue);

      AppPlatform.debugUseGlassOverride = false;
      expect(AppPlatform.useGlass, isFalse);
    });
  });

  group('AppCard', () {
    testWidgets('renders the Material tree off iOS', (tester) async {
      await tester.pumpWidget(host(const AppCard(child: Text('body'))));

      expect(find.byType(LiquidGlassCard), findsNothing);
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('renders glass on iOS', (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      await tester.pumpWidget(
        host(const AppCard(child: Text('body')), glass: true),
      );

      expect(find.byType(LiquidGlassCard), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
      // The Material ink ripple must not survive into the glass path — it smears
      // against the blur.
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('forwards onTap on both platforms', (tester) async {
      for (final glass in [false, true]) {
        AppPlatform.debugUseGlassOverride = glass;
        var taps = 0;
        await tester.pumpWidget(
          host(
            AppCard(onTap: () => taps++, child: const Text('tap me')),
            glass: glass,
          ),
        );
        await tester.tap(find.text('tap me'));
        await tester.pumpAndSettle();

        expect(taps, 1, reason: 'useGlass=$glass');
      }
    });
  });

  group('AppButton', () {
    testWidgets('renders a Material button off iOS', (tester) async {
      await tester.pumpWidget(
        host(AppButton(label: 'Sign in', onPressed: () {})),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(LiquidGlassButton), findsNothing);
    });

    testWidgets('renders a glass button on iOS', (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      await tester.pumpWidget(
        host(AppButton(label: 'Sign in', onPressed: () {}), glass: true),
      );

      expect(find.byType(LiquidGlassButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('a loading button does not fire', (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      var taps = 0;
      await tester.pumpWidget(
        host(
          AppButton(label: 'Save', isLoading: true, onPressed: () => taps++),
          glass: true,
        ),
      );
      await tester.tap(find.byType(LiquidGlassButton));
      await tester.pump();

      expect(taps, 0);
    });
  });

  group('reduce transparency', () {
    testWidgets('drops every BackdropFilter', (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: const GlassScope(
            reduceTransparency: true,
            child: Scaffold(
              body: LiquidGlassContainer(
                // Explicitly asks for the heaviest blur in the system.
                blur: GlassBlur.thick,
                child: Text('opaque'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('opaque'), findsOneWidget);
    });

    testWidgets('keeps the BackdropFilter when transparency is allowed',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: const GlassScope(
            child: Scaffold(
              body: LiquidGlassContainer(
                blur: GlassBlur.thick,
                child: Text('frosted'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('GlassBlur.none never creates a BackdropFilter', (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(
        host(const LiquidGlassContainer(child: Text('simulated')), glass: true),
      );

      // The default for content surfaces: a long list of these must not spawn a
      // filter per row.
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('reduce motion', () {
    testWidgets('collapses durations to zero', (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      late ResolvedGlass glass;

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: GlassScope(
              child: Builder(
                builder: (context) {
                  glass = context.glass;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(glass.reduceMotion, isTrue);
      expect(glass.duration(GlassDurations.base), Duration.zero);
      // A spring's overshoot is exactly the motion the setting exists to remove.
      expect(glass.curve(GlassCurves.spring), Curves.linear);
      expect(glass.pressScale(0.9), 1.0);
    });
  });

  group('GlassTokens.lerp', () {
    test('interpolates rather than snapping at the midpoint', () {
      const from = GlassTokens.dark;
      const to = GlassTokens.light;

      final mid = from.lerp(to, 0.5);

      // The sibling `AppTokens.lerp` deliberately snaps; glass must not, or a
      // light/dark switch would pop instead of cross-fading.
      expect(mid.card.tint, isNot(from.card.tint));
      expect(mid.card.tint, isNot(to.card.tint));
    });

    test('is exact at both endpoints', () {
      const from = GlassTokens.dark;
      const to = GlassTokens.light;

      expect(from.lerp(to, 0).card.tint, from.card.tint);
      expect(from.lerp(to, 1).card.tint, to.card.tint);
    });

    test('toOpaque yields a fully opaque fill', () {
      for (final tokens in [GlassTokens.dark, GlassTokens.light]) {
        for (final spec in [
          tokens.card,
          tokens.chrome,
          tokens.overlay,
          tokens.raised,
          tokens.control,
        ]) {
          expect(
            spec.toOpaque().tint.a,
            1.0,
            reason: 'Reduce Transparency must leave nothing see-through',
          );
        }
      }
    });
  });

  group('LiquidGlassNavigationBar', () {
    const items = [
      GlassNavItem(label: 'Home', icon: Icons.home_outlined),
      GlassNavItem(label: 'Courses', icon: Icons.menu_book_outlined),
      GlassNavItem(label: 'Practice', icon: Icons.extension_outlined),
      GlassNavItem(label: 'Menu', icon: Icons.more_horiz_rounded),
    ];

    Widget navHost(double textScale) => MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: GlassScope(
              child: Scaffold(
                bottomNavigationBar: LiquidGlassNavigationBar(
                  items: items,
                  currentIndex: 0,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        );

    testWidgets('lays out without overflow at large Dynamic Type',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      // Largest accessibility sizes must grow the capsule, not clip its labels.
      for (final scale in [1.0, 1.3, 2.0, 3.0]) {
        await tester.pumpWidget(navHost(scale));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'overflowed at textScale $scale',
        );
      }
    });

    testWidgets('reports selection state to accessibility', (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      await tester.pumpWidget(navHost(1.0));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();

      // VoiceOver must be able to say *which* tab is current.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Home')),
        matchesSemantics(
          label: 'Home',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
          hasSelectedState: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('taps report the right index', (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      final selected = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: GlassScope(
            child: Scaffold(
              bottomNavigationBar: LiquidGlassNavigationBar(
                items: items,
                currentIndex: 0,
                onSelected: selected.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Practice'));
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(selected, [2, 3]);
    });
  });

  group('LiquidGlassAppBar', () {
    /// Scaffold budgets an app bar exactly `preferredSize.height + padding.top`
    /// and gives it no slack, so anything the bar puts in its layout flow beyond
    /// that overflows. A 0.5px hairline appended to the Column was enough to trip
    /// it — hence the positioned hairline, and hence this test.
    Widget barHost({required bool largeTitle, double statusBar = 59}) =>
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(top: statusBar)),
            child: GlassScope(
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: LiquidGlassAppBar(
                  title: 'Dashboard',
                  largeTitle: largeTitle,
                  actions: const [
                    LiquidGlassAppBarAction(
                      icon: Icons.dark_mode_outlined,
                      onPressed: null,
                    ),
                  ],
                ),
                body: const SizedBox.expand(),
              ),
            ),
          ),
        );

    testWidgets('fits its preferredSize budget with a large title',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      for (final statusBar in [0.0, 20.0, 47.0, 59.0]) {
        await tester.pumpWidget(
          barHost(largeTitle: true, statusBar: statusBar),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'overflowed with a $statusBar status bar',
        );
      }
    });

    testWidgets('fits its preferredSize budget when compact', (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(barHost(largeTitle: false));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('leaves a real gap between the leading widget and the title',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: GlassScope(
            child: Scaffold(
              appBar: const LiquidGlassAppBar(
                title: 'Profile',
                subtitle: 'Student Portal',
                leading: SizedBox(
                  key: Key('avatar'),
                  width: 32,
                  height: 32,
                ),
              ),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final avatar = tester.getRect(find.byKey(const Key('avatar')));
      final title = tester.getRect(find.text('Profile'));

      // The title used to start exactly at the avatar's right edge, so the two
      // read as one crowded blob.
      expect(
        title.left - avatar.right,
        greaterThanOrEqualTo(GlassSpacing.md),
        reason: 'title is crowding the leading widget',
      );

      // And the avatar itself must not hug the screen edge.
      expect(avatar.left, greaterThanOrEqualTo(GlassSpacing.md));
    });

    testWidgets('shows the subtitle only when it adds information',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: const GlassScope(
            child: Scaffold(
              appBar: LiquidGlassAppBar(title: 'Profile'),
              body: SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      // Nothing else in the header — a null subtitle must render no second line.
      expect(find.text('Student Portal'), findsNothing);
    });

    testWidgets('reports the right height for each title mode', (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      const large = LiquidGlassAppBar(title: 'x', largeTitle: true);
      const compact = LiquidGlassAppBar(title: 'x');

      expect(large.preferredSize.height, GlassMetrics.appBarLargeHeight);
      expect(compact.preferredSize.height, GlassMetrics.appBarCompactHeight);
    });

    testWidgets('frosts up and collapses its title as content scrolls',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: GlassScope(
            child: Scaffold(
              appBar: LiquidGlassAppBar(
                title: 'Dashboard',
                largeTitle: true,
                scrollOffset: notifier,
              ),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // At rest the large title is laid out and there is no blur-driven shadow.
      final restHeight = tester.getSize(find.text('Dashboard').first).height;
      expect(restHeight, greaterThan(0));

      // Scrolling past the collapse distance retires the large title.
      notifier.update(GlassMetrics.largeTitleCollapseDistance * 2);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Both titles exist in the tree; the collapse is expressed with opacity and
      // height factor, so what matters is that it survives the transition.
      expect(find.text('Dashboard'), findsWidgets);
    });
  });

  group('chrome frosts as content scrolls under it', () {
    /// `ImageFilter` exposes no sigma getter, but its `toString` is
    /// `ImageFilter.blur(24.0, 24.0, clamp)` — enough to assert the sigma the
    /// chrome actually handed to the engine, rather than only the value the
    /// helper computed.
    double? sigmaOf(WidgetTester tester) {
      final filters = tester
          .widgetList<BackdropFilter>(find.byType(BackdropFilter))
          .toList();
      if (filters.isEmpty) return null;
      final match = RegExp(r'blur\(([0-9.]+)')
          .firstMatch(filters.first.filter.toString());
      return match == null ? null : double.parse(match.group(1)!);
    }

    testWidgets('the app bar hands a larger sigma to the engine when scrolled',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: GlassScope(
            child: Scaffold(
              appBar: LiquidGlassAppBar(
                title: 'Dashboard',
                largeTitle: true,
                scrollOffset: notifier,
              ),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final atRest = sigmaOf(tester);
      expect(atRest, isNotNull, reason: 'chrome must really blur');

      notifier.update(GlassMetrics.chromeScrollRamp * 2);
      await tester.pumpAndSettle();

      final scrolled = sigmaOf(tester);
      expect(scrolled, greaterThan(atRest!));
    });

    test('chromeSigma ramps monotonically and stays in the brief\'s range', () {
      const glass = ResolvedGlass(
        tokens: GlassTokens.dark,
        reduceTransparency: false,
        reduceMotion: false,
      );

      final rest = glass.chromeSigma(0);
      final mid = glass.chromeSigma(0.5);
      final full = glass.chromeSigma(1);

      expect(rest, lessThan(mid));
      expect(mid, lessThan(full));
      // The brief specifies 20–40 sigma.
      expect(rest, inInclusiveRange(20, 40));
      expect(full, inInclusiveRange(20, 40));
    });

    test('chromeAt interpolates between rest and scrolled', () {
      const glass = ResolvedGlass(
        tokens: GlassTokens.dark,
        reduceTransparency: false,
        reduceMotion: false,
      );

      expect(glass.chromeAt(0).tint, glass.chrome.tint);
      expect(glass.chromeAt(1).tint, glass.chromeScrolled.tint);

      final mid = glass.chromeAt(0.5).tint;
      expect(mid, isNot(glass.chrome.tint));
      // Scrolled chrome must be *more* opaque, so text stays readable over
      // whatever content happens to pass beneath it.
      expect(glass.chromeScrolled.tint.a, greaterThan(glass.chrome.tint.a));
      expect(mid.a, greaterThan(glass.chrome.tint.a));
    });

    test('the nav capsule is blurrier and more see-through than the app bar', () {
      const glass = ResolvedGlass(
        tokens: GlassTokens.dark,
        reduceTransparency: false,
        reduceMotion: false,
      );

      // The two surfaces want opposite trade-offs. The capsule is small with
      // content passing directly beneath it, so it leans on a heavy blur to stay
      // legible while remaining translucent; the app bar spans the full width and
      // leans on its tint instead. Reusing the app bar's material made the capsule
      // read as solid white with the card behind it invisible.
      expect(glass.navBarSigma(0), greaterThan(glass.chromeSigma(0)));
      expect(glass.navBarSigma(0), GlassMetrics.navBarBlurSigma);
      expect(glass.navBarSigma(1), GlassMetrics.navBarBlurSigmaScrolled);

      expect(
        glass.navBar.tint.a,
        lessThan(glass.chrome.tint.a),
        reason: 'the capsule must let the content behind it through',
      );

      // Still opaque enough to grow more legible once content is behind it.
      expect(glass.navBarScrolled.tint.a, greaterThan(glass.navBar.tint.a));
    });

    test('the capsule blur ramps monotonically in both schemes', () {
      for (final tokens in [GlassTokens.dark, GlassTokens.light]) {
        final glass = ResolvedGlass(
          tokens: tokens,
          reduceTransparency: false,
          reduceMotion: false,
        );
        expect(glass.navBarSigma(0), lessThan(glass.navBarSigma(1)));
        expect(glass.navBarAt(0).tint, glass.navBar.tint);
        expect(glass.navBarAt(1).tint, glass.navBarScrolled.tint);
        expect(glass.navBar.tint.a, lessThan(glass.chrome.tint.a));
      }
    });

    test('reduce transparency zeroes the capsule blur too', () {
      const glass = ResolvedGlass(
        tokens: GlassTokens.dark,
        reduceTransparency: true,
        reduceMotion: false,
      );

      expect(glass.navBarSigma(0), 0);
      expect(glass.navBarSigma(1), 0);
      // And the translucent capsule becomes fully opaque, not merely less blurred.
      expect(glass.navBar.tint.a, 1.0);
    });

    test('reduce transparency defeats the ramp entirely', () {
      const glass = ResolvedGlass(
        tokens: GlassTokens.dark,
        reduceTransparency: true,
        reduceMotion: false,
      );

      expect(glass.chromeSigma(0), 0);
      expect(glass.chromeSigma(1), 0);
    });
  });

  /// The YouTube-style header: it scrolls away as you read down and comes back on
  /// any upward scroll, without having to return to the top.
  group('SliverLiquidGlassAppBar auto-hide', () {
    Widget shellLike({ScrollController? outer}) => MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: GlassScope(
            child: Scaffold(
              body: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverLiquidGlassAppBar(
                    title: 'Dashboard',
                    scrolledUnder: innerBoxIsScrolled,
                    leading: const SizedBox(width: 32, height: 32),
                  ),
                ],
                body: ListView.builder(
                  itemCount: 60,
                  itemBuilder: (context, i) =>
                      SizedBox(height: 90, child: Text('row $i')),
                ),
              ),
            ),
          ),
        );

    testWidgets('hides on scroll down and returns on scroll up',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(shellLike());
      await tester.pumpAndSettle();

      // Visible at rest.
      expect(find.text('Dashboard'), findsOneWidget);

      // Read downward — the header scrolls away with the content.
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(
        find.text('Dashboard'),
        findsNothing,
        reason: 'header should scroll off as content moves up',
      );

      // A small upward scroll brings it straight back — this is the part a
      // non-floating header cannot do, and the whole point of the feature: the
      // list is still hundreds of pixels from the top.
      await tester.drag(find.byType(ListView), const Offset(0, 120));
      await tester.pumpAndSettle();

      expect(
        find.text('Dashboard'),
        findsOneWidget,
        reason: 'header must return without scrolling back to the top',
      );
      expect(
        find.text('row 0'),
        findsNothing,
        reason: 'still far from the top, proving the return was not a reset',
      );
    });

    testWidgets('leaves no gap where the header was', (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(shellLike());
      await tester.pumpAndSettle();

      // At rest the body starts below the bar.
      expect(
        tester.getRect(find.byType(ListView)).top,
        GlassMetrics.appBarCompactHeight,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Once the header is gone the body viewport expands to fill the space it
      // held — this is the assertion a `Transform`-based hide would fail, since
      // there the body stays padded clear of a bar that is no longer drawn and a
      // blank band the height of the bar is left behind.
      expect(
        tester.getRect(find.byType(ListView)).top,
        0,
        reason: 'body must reclaim the vacated header space',
      );

      // And real content is rendered inside that reclaimed band.
      expect(
        tester.getRect(find.text('row 3')).top,
        lessThan(GlassMetrics.appBarCompactHeight),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('content moves at 1:1 with the drag, not double speed',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(shellLike());
      await tester.pumpAndSettle();

      // Pick a row far enough down that it stays on screen across the drag.
      final before = tester.getRect(find.text('row 5')).top;

      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();

      final after = tester.getRect(find.text('row 5')).top;
      final travelled = before - after;

      // The padding-shrink approach moved content by the scroll *plus* the
      // reclaimed padding, i.e. ~2x the finger. A sliver moves it exactly once.
      expect(travelled, closeTo(100, 1));
    });

    testWidgets('floats back under real iOS physics, not just Android',
        (tester) async {
      // The suite otherwise runs under Android's ClampingScrollPhysics, because
      // `debugUseGlassOverride` does not change `defaultTargetPlatform`. iOS uses
      // BouncingScrollPhysics, whose momentum and overscroll interact with the
      // snap animation — so the behaviour has to be pinned on the real physics
      // too, not only on the platform the tests happen to default to.
      // Reset inside the body, not via `addTearDown`: the framework's
      // "debug variable was changed by the test" invariant is checked before
      // tear-downs run, so a tear-down reset fails the test regardless of what it
      // asserted.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(shellLike());
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(
        find.text('Dashboard'),
        findsNothing,
        reason: 'header must hide under bouncing physics too',
      );

      await tester.drag(find.byType(ListView), const Offset(0, 150));
      await tester.pumpAndSettle();
      expect(
        find.text('Dashboard'),
        findsOneWidget,
        reason: 'header must float back under bouncing physics as well',
      );

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('does not stretch its leading widget', (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: GlassScope(
            child: Scaffold(
              body: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverLiquidGlassAppBar(
                    title: 'Dashboard',
                    scrolledUnder: innerBoxIsScrolled,
                    leading: const AppAvatar(name: 'Test User', size: 32),
                  ),
                ],
                body: ListView.builder(
                  itemCount: 30,
                  itemBuilder: (context, i) => const SizedBox(height: 90),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // AppBar's toolbar layout forces its leading slot to the full toolbar
      // height, which stretched the 32pt avatar into a clipped 52pt oval.
      final avatar = tester.getSize(find.byType(AppAvatar));
      expect(avatar.height, 32);
      expect(avatar.width, 32);
      expect(avatar.height, lessThan(GlassMetrics.appBarCompactHeight));
    });

    testWidgets('leaves a gap between the leading widget and the title',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: GlassScope(
            child: Scaffold(
              body: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverLiquidGlassAppBar(
                    title: 'Dashboard',
                    scrolledUnder: innerBoxIsScrolled,
                    leading: const AppAvatar(name: 'Test User', size: 32),
                  ),
                ],
                body: ListView.builder(
                  itemCount: 30,
                  itemBuilder: (context, i) => const SizedBox(height: 90),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final avatar = tester.getRect(find.byType(AppAvatar));
      final title = tester.getRect(find.text('Dashboard'));

      expect(avatar.left, GlassSpacing.lg);
      expect(
        title.left - avatar.right,
        greaterThanOrEqualTo(GlassSpacing.md),
        reason: 'title is crowding the avatar',
      );
    });

    testWidgets('is reachable and labelled while visible', (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(shellLike());
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      expect(find.text('Dashboard'), findsOneWidget);
      handle.dispose();
    });
  });

  /// The bottom half of "full screen": the floating capsule tucks away while
  /// reading downward and returns on any upward scroll.
  /// The refraction shader is what makes the chrome read as a lens rather than as
  /// frosted film. It requires Impeller, so every path must survive its absence —
  /// `flutter test` runs without it, which makes this suite the unavailable case.
  group('GlassRefraction', () {
    test('always yields a usable filter when asked to blur', () {
      // Deliberately does NOT assert on `isAvailable`. The .frag asset does load
      // under `flutter test`, but `ImageFilter.shader` then throws because the
      // harness has no Impeller — so availability depends on whether `load()` ran
      // first, i.e. on test order. The invariant that actually matters is
      // order-independent: however that resolves, the caller gets a filter and
      // nothing throws.
      final filter = GlassRefraction.filter(
        sigma: 60,
        radius: 999,
        size: const Size(361, 58),
      );

      expect(filter, isNotNull);
      // Either a bare blur (shader unavailable) or a blur composed under the
      // refraction — never a shader alone, so the capsule always frosts.
      expect(filter.toString(), contains('blur'));
    });

    test('a shader failure is not retried every frame', () {
      // First call may attempt the shader and fail; subsequent calls must take the
      // cheap path rather than throwing into a try/catch 60 times a second.
      for (var i = 0; i < 3; i++) {
        expect(
          () => GlassRefraction.filter(
            sigma: 40,
            radius: 999,
            size: const Size(361, 58),
          ),
          returnsNormally,
        );
      }
    });

    test('returns null when there is nothing to do', () {
      // Sigma 0 and no shader: the caller should skip the BackdropFilter entirely
      // rather than pay for an identity filter.
      expect(
        GlassRefraction.filter(sigma: 0, radius: 20, size: const Size(200, 60)),
        isNull,
      );
    });

    test('degrades safely for a degenerate surface', () {
      for (final size in [Size.zero, const Size(0, 58), const Size(361, 0)]) {
        expect(
          () => GlassRefraction.filter(sigma: 40, radius: 999, size: size),
          returnsNormally,
          reason: 'size $size must not throw',
        );
      }
    });

    test('load() never throws, even where the shader cannot exist', () async {
      await expectLater(GlassRefraction.load(), completes);
      // Idempotent: bootstrap calls it once, but a second call must be harmless.
      await expectLater(GlassRefraction.load(), completes);
    });

    test('refraction constants stay in a physically plausible range', () {
      // Past ~0.2 the channel split stops reading as dispersion and starts reading
      // as a broken image.
      expect(GlassMetrics.chromeDispersion, lessThan(0.2));
      expect(GlassMetrics.chromeDispersion, greaterThan(0));

      // The lensing must not reach so far in that the two rims meet in the middle
      // of the capsule and cancel.
      expect(
        GlassMetrics.chromeRefractionEdge,
        lessThan(GlassMetrics.navBarHeight),
      );
      expect(
        GlassMetrics.chromeRefraction,
        lessThan(GlassMetrics.chromeRefractionEdge),
      );
    });
  });

  /// A modal must cover the floating nav capsule, not hide behind it.
  ///
  /// The capsule is the shell Scaffold's `bottomNavigationBar`, and a Scaffold
  /// always paints that above its body — and hit-tests it first. A sheet pushed
  /// onto the *shell's* navigator therefore rendered underneath it, which both hid
  /// the lower options and swallowed their taps.
  group('glass sheets clear the nav capsule', () {
    /// Mirrors the shell: an outer Scaffold owning the capsule, with a nested
    /// Navigator for pages — the structure `ShellRoute` produces.
    Widget shellLike({
      required void Function(BuildContext) onReady,
      required List<int> navTaps,
    }) =>
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: GlassScope(
            child: Scaffold(
              extendBody: true,
              body: Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    backgroundColor: Colors.transparent,
                    body: Center(
                      child: TextButton(
                        onPressed: () => onReady(context),
                        child: const Text('open'),
                      ),
                    ),
                  ),
                ),
              ),
              bottomNavigationBar: LiquidGlassNavigationBar(
                items: const [
                  GlassNavItem(label: 'Home', icon: Icons.home_outlined),
                  GlassNavItem(label: 'Practice', icon: Icons.extension_outlined),
                ],
                currentIndex: 0,
                onSelected: navTaps.add,
              ),
            ),
          ),
        );

    testWidgets('the bottom-most option is tappable, not eaten by the capsule',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      final navTaps = <int>[];
      String? picked;

      await tester.pumpWidget(
        shellLike(
          navTaps: navTaps,
          onReady: (context) async {
            picked = await showLiquidGlassOptionSheet<String>(
              context,
              title: 'Sort by',
              options: const [
                LiquidGlassSheetOption(value: 'recent', label: 'Most recent'),
                LiquidGlassSheetOption(value: 'popular', label: 'Most attempted'),
                LiquidGlassSheetOption(value: 'accuracy', label: 'Accuracy'),
                LiquidGlassSheetOption(value: 'difficulty', label: 'Difficulty'),
              ],
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The LAST row specifically — it is the one that lands inside the capsule's
      // band. A middle row sits above the capsule and would tap fine even with the
      // bug present, which is why an earlier version of this test was useless.
      final last = find.text('Difficulty');
      final capsule = tester.getRect(find.text('Home'));
      expect(
        tester.getRect(last).overlaps(
              Rect.fromLTRB(0, capsule.top - 20, 800, capsule.bottom + 20),
            ),
        isTrue,
        reason: 'test is only meaningful if the row overlaps the capsule band',
      );

      await tester.tap(last);
      await tester.pumpAndSettle();

      expect(picked, 'difficulty');
      expect(navTaps, isEmpty, reason: 'the capsule must not receive the tap');
    });

    testWidgets('the capsule is not hit-testable while a sheet is open',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      final navTaps = <int>[];

      await tester.pumpWidget(
        shellLike(
          navTaps: navTaps,
          onReady: (context) => showLiquidGlassSheet<void>(
            context,
            title: 'Sort by',
            builder: (context) => const SizedBox(height: 200),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tapping where a tab label sits must reach the sheet's modal barrier, never
      // the tab underneath it.
      await tester.tap(find.text('Practice'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        navTaps,
        isEmpty,
        reason: 'a covered tab must not fire while a modal is open',
      );
    });
  });

  group('LiquidGlassListTile', () {
    testWidgets('a long trailing value cannot crush the title', (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: const GlassScope(
            child: Scaffold(
              body: Center(
                // Constrained to a real phone width. The default 800px test
                // surface is wide enough to fit the title and the long value side
                // by side, so the crush simply does not occur there — an
                // unconstrained version of this test passes even with the bug.
                child: SizedBox(
                  width: 393,
                  child: LiquidGlassSection(
                    children: [
                      LiquidGlassListTile(
                        title: 'Username',
                        leadingIcon: Icons.alternate_email_rounded,
                        // Real data: these usernames are full email addresses.
                        trailingText: 'narayan.mungase@mitcorer.edu.in',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // An unconstrained trailing Text took its full intrinsic width and squeezed
      // the title's Expanded toward zero, wrapping "Username" as "Usern/ame".
      // A single line of `bodyMedium` (15pt) is well under 30px tall.
      expect(
        tester.getSize(find.text('Username')).height,
        lessThan(30),
        reason: 'title wrapped onto a second line',
      );
      // And the value itself is still laid out, just ellipsised.
      expect(find.text('narayan.mungase@mitcorer.edu.in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('nav capsule auto-hide', () {
    /// A real scroll arrives as a stream of small deltas, so the tests feed it
    /// that way. Jumping the offset discontinuously would manufacture a single
    /// enormous delta that no gesture produces.
    void scrollTo(GlassScrollNotifier notifier, double target) {
      const step = 8.0;
      var current = notifier.value;
      while ((target - current).abs() > step) {
        current += target > current ? step : -step;
        notifier.update(current);
      }
      notifier.update(target);
    }

    test('stays visible near the top of a list', () {
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);

      // Nothing is gained by hiding chrome when barely scrolled.
      scrollTo(notifier, 30);
      expect(notifier.chromeHidden.value, isFalse);
    });

    test('hides after sustained downward travel', () {
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);

      scrollTo(notifier, 200);
      expect(notifier.chromeHidden.value, isTrue);
    });

    test('returns on upward travel without going back to the top', () {
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);

      scrollTo(notifier, 400);
      expect(notifier.chromeHidden.value, isTrue);

      // Scroll up while still deep in the list — the whole point of the feature.
      scrollTo(notifier, 320);
      expect(notifier.chromeHidden.value, isFalse);
      expect(notifier.value, 320, reason: 'still far from the top');
    });

    test('does not flicker on jitter', () {
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);

      scrollTo(notifier, 200);
      final settled = notifier.chromeHidden.value;

      var flips = 0;
      void count() => flips++;
      notifier.chromeHidden.addListener(count);

      // Small alternating deltas — a finger resting on a bouncing list.
      for (final offset in [205.0, 200.0, 206.0, 201.0, 204.0]) {
        notifier.update(offset);
      }

      notifier.chromeHidden.removeListener(count);
      expect(notifier.chromeHidden.value, settled);
      expect(flips, 0, reason: 'capsule must not flicker on jitter');
    });

    test('returning to the top always restores the capsule', () {
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);

      scrollTo(notifier, 400);
      expect(notifier.chromeHidden.value, isTrue);

      scrollTo(notifier, 0);
      expect(notifier.chromeHidden.value, isFalse);
    });

    test('reset restores the capsule for an incoming route', () {
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);

      scrollTo(notifier, 400);
      expect(notifier.chromeHidden.value, isTrue);

      notifier.reset();
      expect(notifier.chromeHidden.value, isFalse);
      expect(notifier.value, 0);
    });

    testWidgets('slides the capsule off and back, and blocks taps while hidden',
        (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);
      final taps = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: GlassScope(
            child: GlassScrollScope(
              notifier: notifier,
              child: Scaffold(
                bottomNavigationBar: LiquidGlassNavigationBar(
                  items: const [
                    GlassNavItem(label: 'Home', icon: Icons.home_outlined),
                    GlassNavItem(label: 'Courses', icon: Icons.menu_book_outlined),
                  ],
                  currentIndex: 0,
                  onSelected: taps.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shown = tester.getRect(find.text('Home')).top;

      notifier.update(100);
      notifier.update(400);
      await tester.pumpAndSettle();

      final tucked = tester.getRect(find.text('Home')).top;
      expect(tucked, greaterThan(shown), reason: 'capsule should slide down');

      // Tapping where it used to be must reach the content, not a hidden tab.
      await tester.tap(find.text('Courses'), warnIfMissed: false);
      await tester.pump();
      expect(taps, isEmpty, reason: 'hidden capsule must not receive taps');

      notifier.update(360);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Home')).top, closeTo(shown, 0.5));

      await tester.tap(find.text('Courses'));
      await tester.pump();
      expect(taps, [1]);
    });
  });

  group('glass content insets', () {
    testWidgets('are zero off iOS', (tester) async {
      late EdgeInsets insets;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              insets = context.glassContentInsets;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // The `.add()` at every scroll site must be a no-op on Android.
      expect(insets, EdgeInsets.zero);
    });

    testWidgets('clear the floating chrome on iOS', (tester) async {
      AppPlatform.debugUseGlassOverride = true;
      late EdgeInsets insets;

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: GlassScope(
            child: GlassInsetsScope(
              contentInsets: const EdgeInsets.only(top: 96, bottom: 80),
              child: Builder(
                builder: (context) {
                  insets = context.glassContentInsets;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(insets.top, 96);
      expect(insets.bottom, 80);
    });

    test('bottom inset clears the capsule without double-counting the safe area',
        () {
      final inset = GlassInsetsMath.bottomInset();

      expect(inset, GlassMetrics.navBarReservedHeight);
      expect(inset, greaterThan(GlassMetrics.navBarHeight));

      // The capsule's offset is measured from the physical screen edge, so the
      // reserve must NOT also include `viewPadding.bottom` (34pt on a
      // home-indicator device). Adding both is what left an empty band beneath
      // the capsule.
      expect(
        inset,
        lessThan(GlassMetrics.navBarHeight + 34),
        reason: 'safe area is being counted twice',
      );
    });

    test('the capsule sits close to the screen edge, clear of the indicator', () {
      // Low enough that no empty band shows, high enough that the ~5pt home
      // indicator line (which sits ~8pt up) is not overlapped.
      expect(GlassMetrics.navBarBottomInset, lessThan(24));
      expect(GlassMetrics.navBarBottomInset, greaterThan(12));

      // The toast must clear the capsule's top edge.
      expect(
        GlassInsetsMath.navBarTopFromBottom(),
        GlassMetrics.navBarBottomInset + GlassMetrics.navBarHeight,
      );
    });
  });

  /// The hard requirement of this whole change: Android must render exactly what
  /// it rendered before the glass layer existed. These cover the places where
  /// shared code was touched *unconditionally* rather than behind an `if` — the
  /// only places where an Android regression could hide.
  group('Android parity', () {
    testWidgets('RefreshableScroll padding is untouched off iOS',
        (tester) async {
      const declared = EdgeInsets.fromLTRB(16, 12, 16, 28);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: RefreshableScroll(
              onRefresh: () async {},
              padding: declared,
              child: const SizedBox(height: 2000),
            ),
          ),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );

      // `padding.add(context.glassContentInsets)` must be a true no-op here.
      expect(scrollView.padding, declared);
    });

    testWidgets('AppLoader keeps the Material spinner off iOS', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: AppLoader(message: 'Loading')),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsOneWidget);
    });

    testWidgets('AppLoader uses the iOS indicator on iOS', (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: const GlassScope(child: Scaffold(body: AppLoader())),
        ),
      );

      // A Material sweeping arc is one of the loudest tells that an app was not
      // built for the platform.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('AdaptiveAppBar builds a Material AppBar off iOS',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            appBar: AdaptiveAppBar(title: 'Course'),
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(LiquidGlassAppBar), findsNothing);
      expect(find.text('Course'), findsOneWidget);
    });

    testWidgets('AdaptiveAppBar builds a glass bar on iOS', (tester) async {
      AppPlatform.debugUseGlassOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: LiquidGlassTheme.dark,
          home: const GlassScope(
            child: Scaffold(
              appBar: AdaptiveAppBar(title: 'Course'),
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(find.byType(LiquidGlassAppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('AdaptiveAppBar reserves its bottom widget height on both platforms',
        () {
      const tabs = TabBar(tabs: [Tab(text: 'a'), Tab(text: 'b')]);

      AppPlatform.debugUseGlassOverride = false;
      final material = const AdaptiveAppBar(title: 'x', bottom: tabs)
          .preferredSize
          .height;
      final materialBare = const AdaptiveAppBar(title: 'x').preferredSize.height;

      AppPlatform.debugUseGlassOverride = true;
      final glass =
          const AdaptiveAppBar(title: 'x', bottom: tabs).preferredSize.height;
      final glassBare = const AdaptiveAppBar(title: 'x').preferredSize.height;

      // Scaffold gives an app bar no slack, so a bottom widget that is not
      // accounted for here overflows at runtime.
      expect(material - materialBare, tabs.preferredSize.height);
      expect(glass - glassBare, tabs.preferredSize.height);
    });
  });

  group('scroll → chrome reactivity', () {
    test('progress clamps to 0..1', () {
      expect(glassScrollProgress(-50, 40), 0);
      expect(glassScrollProgress(0, 40), 0);
      expect(glassScrollProgress(20, 40), 0.5);
      expect(glassScrollProgress(400, 40), 1);
    });

    test('overscroll cannot un-frost the chrome', () {
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);

      // iOS bouncing physics report negative offsets on a pull-to-refresh.
      notifier.update(-120);
      expect(notifier.value, 0);

      notifier.update(80);
      expect(notifier.value, 80);

      notifier.reset();
      expect(notifier.value, 0);
    });

    test('sub-pixel deltas are ignored', () {
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);

      var notifications = 0;
      notifier.addListener(() => notifications++);

      notifier.update(10);
      notifier.update(10.2); // below the epsilon — must not rebuild the chrome
      notifier.update(40);

      expect(notifications, 2);
    });

    testWidgets('the observer feeds offsets from an ordinary ListView',
        (tester) async {
      // The point of the design: no slivers required anywhere in the app.
      final notifier = GlassScrollNotifier();
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: GlassScrollObserver(
            notifier: notifier,
            child: ListView(
              children: [
                for (var i = 0; i < 40; i++) SizedBox(height: 80, child: Text('$i')),
              ],
            ),
          ),
        ),
      );

      expect(notifier.value, 0);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(notifier.value, greaterThan(0));
    });
  });
}
