import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:college_level/core/config/theme/reduce_transparency_cubit.dart';
import 'package:college_level/core/config/theme/theme_cubit.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/shared/auth/domain/entities/auth_session.dart';
import 'package:college_level/features/shared/auth/domain/entities/user.dart';
import 'package:college_level/features/shared/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:college_level/features/student/practice/domain/entities/daily_challenge.dart';
import 'package:college_level/features/student/practice/domain/entities/practice_question.dart';
import 'package:college_level/features/student/practice/domain/usecases/practice_usecases.dart';
import 'package:college_level/features/student/practice/presentation/bloc/daily_challenge_cubit.dart';
import 'package:college_level/features/student/practice/presentation/bloc/practice_list_cubit.dart';
import 'package:college_level/features/student/practice/presentation/pages/daily_challenge_page.dart';
import 'package:college_level/features/student/practice/presentation/pages/practice_page.dart';
import 'package:college_level/features/shared/profile/presentation/pages/profile_page.dart';
import 'package:college_level/features/shared/settings/presentation/pages/settings_page.dart';

import '../support/platform_parity.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _MockListQuestions extends Mock implements ListPracticeQuestionsUseCase {}

class _MockSetBookmarked extends Mock implements SetBookmarkedUseCase {}

class _MockGetFilters extends Mock implements GetPracticeFiltersUseCase {}

class _MockGetToday extends Mock implements GetDailyChallengeUseCase {}

class _MockGetCalendar extends Mock implements GetDailyCalendarUseCase {}

class _MockGetHistory extends Mock implements GetDailyChallengeHistoryUseCase {}

/// The remaining sidebar destinations, pumped down both branches.
///
/// Together with `calendar_parity_test`, `screens_parity_test` and
/// `shared_kit_parity_test` (which covers the one page behind eleven
/// placeholder tabs), this closes the loop on every student destination.
void main() {
  const user = User(
    id: 'u1',
    schoolId: 's1',
    firstName: 'Narayan',
    lastName: 'Mungase',
    email: 'student@example.com',
    username: 'narayan',
    isEmailVerified: true,
    status: 'active',
  );

  late _MockAuthBloc auth;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const PracticeQueryParams());
    registerFallbackValue(const MonthParams());
    registerFallbackValue(
      const SetBookmarkedParams(questionId: 'q', bookmarked: true),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = _MockAuthBloc();
    whenListen(
      auth,
      const Stream<AuthState>.empty(),
      initialState: const AuthState(
        status: AuthStatus.authenticated,
        session: AuthSession(
          user: user,
          roles: [],
          tokens: Tokens(accessToken: 'a', refreshToken: 'r'),
        ),
      ),
    );
  });

  group('Profile', () {
    bothPlatforms('shows the signed-in student and their details',
        (tester, host) async {
      await tester.pumpWidget(
        host(
          BlocProvider<AuthBloc>.value(value: auth, child: const ProfilePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Narayan Mungase'), findsOneWidget);
      expect(find.text('student@example.com'), findsWidgets);
      expect(find.text('Username'), findsOneWidget);
    });
  });

  group('Settings', () {
    bothPlatforms('offers appearance and the accessibility toggle',
        (tester, host) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        host(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: auth),
              BlocProvider(create: (_) => ThemeCubit(prefs)),
              BlocProvider(create: (_) => ReduceTransparencyCubit(prefs)),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });

  group('Practice', () {
    late _MockListQuestions listQuestions;
    late _MockSetBookmarked setBookmarked;
    late _MockGetFilters getFilters;

    setUp(() {
      listQuestions = _MockListQuestions();
      setBookmarked = _MockSetBookmarked();
      getFilters = _MockGetFilters();

      when(() => listQuestions(any())).thenAnswer(
        (_) async => Right<Failure, Paginated<PracticeQuestionListItem>>(
          Paginated.emptyOf<PracticeQuestionListItem>(),
        ),
      );
      when(() => getFilters(any())).thenAnswer(
        (_) async => const Right<Failure, PracticeFilterOptions>(
          PracticeFilterOptions(),
        ),
      );
    });

    Widget page() => BlocProvider(
          create: (_) => PracticeListCubit(
            listQuestions: listQuestions,
            setBookmarked: setBookmarked,
            getFilters: getFilters,
          ),
          child: const PracticePage(),
        );

    bothPlatforms('renders its list chrome and the filter button',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    bothPlatforms('the filter sheet carries its groups, Reset and Apply',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Sort by'), findsOneWidget);
      expect(find.text('Difficulty'), findsWidgets);
      // The arrangement standardised across all four filter sheets.
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('Daily Challenge', () {
    bothPlatforms('renders the hub once the day has loaded',
        (tester, host) async {
      final getToday = _MockGetToday();
      final getCalendar = _MockGetCalendar();
      final getHistory = _MockGetHistory();

      when(() => getToday(any())).thenAnswer(
        (_) async => const Right<Failure, DailyChallenge>(
          DailyChallenge(
            available: false,
            isOpen: false,
            streak: DailyStreak(
              currentStreak: 0,
              totalPoints: 0,
              challengesCompleted: 0,
            ),
          ),
        ),
      );
      when(() => getCalendar(any())).thenAnswer(
        (_) async => const Left<Failure, DailyCalendar>(ServerFailure('none')),
      );
      when(() => getHistory(any())).thenAnswer(
        (_) async =>
            const Left<Failure, List<DailyChallengeDay>>(ServerFailure('none')),
      );

      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) => DailyChallengeCubit(
              getToday: getToday,
              getCalendar: getCalendar,
              getHistory: getHistory,
            ),
            child: const DailyChallengePage(),
          ),
        ),
      );
      // Not `pumpAndSettle`: with the month fetch failed there is no calendar
      // to draw, so the card holds an `AppSkeleton`, whose shimmer never stops
      // and would time the settle out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The hub resolves rather than sitting on a skeleton, and the history
      // section is present even when its own fetch failed.
      expect(find.byType(DailyChallengePage), findsOneWidget);
      expect(find.text('Recent challenges'), findsOneWidget);
    });
  });
}
