import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/config/theme/app_theme.dart';
import 'package:college_level/core/design/glass.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/features/student/calendar/domain/entities/calendar_entry.dart';
import 'package:college_level/features/student/calendar/domain/entities/calendar_view.dart';
import 'package:college_level/features/student/calendar/domain/usecases/calendar_usecases.dart';
import 'package:college_level/features/student/calendar/presentation/bloc/calendar_cubit.dart';
import 'package:college_level/features/student/calendar/presentation/bloc/today_sessions_cubit.dart';
import 'package:college_level/features/student/calendar/presentation/pages/calendar_page.dart';
import 'package:college_level/features/student/dashboard/presentation/widgets/today_sessions_card.dart';

class _MockGetCalendar extends Mock implements GetCalendarUseCase {}

/// The two rendering paths the app ships: Material everywhere, Liquid Glass on
/// iOS. `defaultTargetPlatform` is hard-wired to Android under `flutter_test`,
/// so the glass branch has to be asked for explicitly.
///
/// These pump the calendar and the dashboard's sessions card down *both*
/// branches, which is the parity check a single-platform device run cannot
/// give.
void main() {
  const day = 'Mon, 17 Aug 2026';

  final session = CalendarEntry(
    id: 'slot-1:2026-08-17',
    parentId: 'slot-1',
    source: CalendarSource.timetable,
    type: CalendarEntryType.lesson,
    title: 'Engineering Physics',
    start: DateTime(2026, 8, 17, 9),
    end: DateTime(2026, 8, 17, 10),
    room: const CalendarLabelRef(id: 'r1', code: 'B-102'),
    teacher: const CalendarPersonRef(id: 't1', name: 'Dr Rao'),
    course: const CalendarLabelRef(id: 'c1', name: 'Physics', code: 'PH101'),
  );

  // The sessions card compares against the real clock, so its fixture is
  // anchored to *now* rather than to a fixed date — otherwise whether a class
  // reads as done or upcoming depends on the hour the suite happens to run.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final finished = CalendarEntry(
    id: 'slot-2:today',
    parentId: 'slot-2',
    source: CalendarSource.timetable,
    type: CalendarEntryType.lesson,
    title: 'Engineering Physics',
    // Anchored to midday today rather than an offset from `now`: "two hours
    // ago" falls on *yesterday* when the suite runs just after midnight, and
    // the card only keeps sessions that start on the day it is showing.
    start: DateTime(now.year, now.month, now.day, 12),
    end: DateTime(now.year, now.month, now.day, 13),
    room: const CalendarLabelRef(id: 'r1', code: 'B-102'),
    teacher: const CalendarPersonRef(id: 't1', name: 'Dr Rao'),
    course: const CalendarLabelRef(id: 'c1', name: 'Physics', code: 'PH101'),
  );

  // Straddles the real clock so the card takes its live-tracker branch. Start
  // is clamped to midnight: a fixed offset back from `now` lands on
  // *yesterday* just after midnight, and the card drops sessions that do not
  // start on the day it is showing.
  final liveStart = now.subtract(const Duration(minutes: 20));
  final live = CalendarEntry(
    id: 'slot-3:today',
    parentId: 'slot-3',
    source: CalendarSource.timetable,
    type: CalendarEntryType.lesson,
    title: 'Engineering Chemistry',
    start: liveStart.isBefore(today) ? today : liveStart,
    end: now.add(const Duration(minutes: 20)),
    room: const CalendarLabelRef(id: 'r2', code: 'A-102'),
    teacher: const CalendarPersonRef(id: 't2', name: 'Dr Rao'),
    course: const CalendarLabelRef(id: 'c2', name: 'Chemistry', code: 'CY101'),
  );

  late _MockGetCalendar getCalendar;

  setUpAll(() {
    registerFallbackValue(
      CalendarQueryParams.of(CalendarViewMode.day, DateTime(2026)),
    );
  });

  setUp(() {
    getCalendar = _MockGetCalendar();
    when(() => getCalendar(any())).thenAnswer(
      (_) async => Right<Failure, List<CalendarEntry>>([session]),
    );
  });

  tearDown(() {
    // A leaked override would silently flip every later test in the run.
    AppPlatform.debugUseGlassOverride = null;
  });

  Widget host(Widget child, {required bool glass}) {
    AppPlatform.debugUseGlassOverride = glass;
    return MaterialApp(
      theme: glass ? LiquidGlassTheme.light : AppTheme.light,
      home: GlassScope(child: child),
    );
  }

  for (final glass in [false, true]) {
    final platform = glass ? 'iOS (glass)' : 'Android (material)';

    group('calendar on $platform', () {
      testWidgets('renders the header, its state line and the day grid',
          (tester) async {
        await tester.pumpWidget(
          host(
            BlocProvider(
              create: (_) => CalendarCubit(
                getCalendar: getCalendar,
                today: DateTime(2026, 8, 17),
              ),
              child: const CalendarPage(),
            ),
            glass: glass,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(day), findsOneWidget);
        // The line that replaced the switcher and the filter strip.
        expect(find.text('Day · All Scheduled'), findsOneWidget);
        expect(find.text('Engineering Physics'), findsOneWidget);
        // Room and teacher on the block's second line.
        expect(find.text('B-102 · Dr Rao'), findsOneWidget);
      });

      testWidgets('the five header actions are all present', (tester) async {
        await tester.pumpWidget(
          host(
            BlocProvider(
              create: (_) => CalendarCubit(
                getCalendar: getCalendar,
                today: DateTime(2026, 8, 17),
              ),
              child: const CalendarPage(),
            ),
            glass: glass,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
        expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
        expect(find.byIcon(Icons.today_rounded), findsOneWidget);
        expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      });

      testWidgets('the filter sheet opens with both groups and the actions',
          (tester) async {
        await tester.pumpWidget(
          host(
            BlocProvider(
              create: (_) => CalendarCubit(
                getCalendar: getCalendar,
                today: DateTime(2026, 8, 17),
              ),
              child: const CalendarPage(),
            ),
            glass: glass,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pumpAndSettle();

        expect(find.text('View'), findsOneWidget);
        expect(find.text('Show'), findsOneWidget);
        expect(find.text('Week'), findsOneWidget);
        expect(find.text('Task Reminders'), findsOneWidget);
        // Reset replaced Cancel, and both sit at the foot rather than the top.
        expect(find.text('Reset'), findsOneWidget);
        expect(find.text('Apply'), findsOneWidget);
      });

      testWidgets('picking a view and applying switches the grid',
          (tester) async {
        await tester.pumpWidget(
          host(
            BlocProvider(
              create: (_) => CalendarCubit(
                getCalendar: getCalendar,
                today: DateTime(2026, 8, 17),
              ),
              child: const CalendarPage(),
            ),
            glass: glass,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();
        // The sheet scrolls; Apply sits below the fold on a short viewport, so
        // reach it the way a user would rather than tapping into empty space.
        await tester.ensureVisible(find.text('Apply'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        expect(find.text('August 2026'), findsOneWidget);
        expect(find.text('Month · All Scheduled'), findsOneWidget);
      });
    });

    group("today's sessions on $platform", () {
      testWidgets('renders the header, the tracker and the timeline',
          (tester) async {
        when(() => getCalendar(any())).thenAnswer(
          (_) async => Right<Failure, List<CalendarEntry>>([finished]),
        );

        await tester.pumpWidget(
          host(
            BlocProvider(
              create: (_) =>
                  TodaySessionsCubit(getCalendar: getCalendar, today: today),
              child: const Scaffold(
                body: SingleChildScrollView(child: TodaySessionsCard()),
              ),
            ),
            glass: glass,
          ),
        );
        // Not `pumpAndSettle`: this fixture sits at midday, so whenever the
        // suite runs inside that window the session is live and its pulsing dot
        // animates forever — settling would wait for an animation that never
        // ends.
        await tester.pump();
        await tester.pump();

        expect(find.text("Today's sessions"), findsOneWidget);
        expect(find.text(DateFormat('EEEE, d MMM').format(today)),
            findsOneWidget);
        // Which phase the class is in depends on the hour the suite runs, so
        // assert the shape of the count rather than a value — `phaseOf` has
        // deterministic boundary tests of its own in calendar_test.dart.
        expect(find.textContaining(RegExp(r'^\d+/1 done$')), findsOneWidget);
        // The timeline row carries the course name and its meta line, whatever
        // the phase.
        expect(find.text('Physics'), findsWidgets);
        expect(find.text('PH101 · B-102 · Dr Rao'), findsOneWidget);
      });

      // The live tracker paints an accent edge down one side. Spelling that as
      // a non-uniform `Border` under a `borderRadius` throws mid-paint, which
      // leaves the box tinted but empty — the phase the other fixtures never
      // reach, so it went unseen. Painting is what this asserts: a finder
      // alone would pass on a box whose paint threw.
      testWidgets('a class in progress paints the live tracker',
          (tester) async {
        when(() => getCalendar(any())).thenAnswer(
          (_) async => Right<Failure, List<CalendarEntry>>([live]),
        );

        await tester.pumpWidget(
          host(
            BlocProvider(
              create: (_) =>
                  TodaySessionsCubit(getCalendar: getCalendar, today: today),
              child: const Scaffold(
                body: SingleChildScrollView(child: TodaySessionsCard()),
              ),
            ),
            glass: glass,
          ),
        );
        // Not `pumpAndSettle`: the pulsing dot animates forever.
        await tester.pump();
        await tester.pump();

        expect(find.text('IN PROGRESS'), findsOneWidget);
        expect(find.text('Chemistry'), findsWidgets);
        expect(find.textContaining('left'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('an empty day shows the no-classes copy', (tester) async {
        when(() => getCalendar(any())).thenAnswer(
          (_) async => const Right<Failure, List<CalendarEntry>>([]),
        );

        await tester.pumpWidget(
          host(
            BlocProvider(
              create: (_) =>
                  TodaySessionsCubit(getCalendar: getCalendar, today: today),
              child: const Scaffold(
                body: SingleChildScrollView(child: TodaySessionsCard()),
              ),
            ),
            glass: glass,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No classes today'), findsOneWidget);
        // No count pill when there is nothing to count.
        expect(find.textContaining('done'), findsNothing);
      });
    });
  }
}
