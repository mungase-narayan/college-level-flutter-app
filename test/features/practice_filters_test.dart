import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/features/practice/domain/entities/practice_question.dart';
import 'package:college_level/features/practice/domain/usecases/practice_usecases.dart';
import 'package:college_level/features/practice/presentation/bloc/practice_list_cubit.dart';

class _MockList extends Mock implements ListPracticeQuestionsUseCase {}

class _MockSetBookmarked extends Mock implements SetBookmarkedUseCase {}

class _MockGetFilters extends Mock implements GetPracticeFiltersUseCase {}

/// The filter sheet stages sort, status and difficulty and commits them together.
/// `setFilters` is what turns that into one request instead of three, and its
/// null-means-cleared contract is easy to get wrong given `copyWith`'s `??`.
void main() {
  late _MockList list;
  late PracticeListCubit cubit;

  /// Every query the use case has been called with, in order.
  List<PracticeQueryParams> capturedQueries() =>
      verify(() => list(captureAny())).captured.cast<PracticeQueryParams>();

  setUpAll(() => registerFallbackValue(const PracticeQueryParams()));

  setUp(() {
    list = _MockList();
    when(() => list(any())).thenAnswer(
      (_) async => Right<Failure, Paginated<PracticeQuestionListItem>>(
        Paginated.emptyOf<PracticeQuestionListItem>(),
      ),
    );
    cubit = PracticeListCubit(
      listQuestions: list,
      setBookmarked: _MockSetBookmarked(),
      getFilters: _MockGetFilters(),
    );
  });

  tearDown(() => cubit.close());

  group('setFilters', () {
    test('issues exactly one request for all three filters', () async {
      await cubit.setFilters(
        sort: 'popular',
        attemptStatus: 'solved',
        difficulty: 'hard',
      );

      // The whole reason this method exists: the three individual setters would
      // fire three requests and paint two throwaway result sets on the way.
      verify(() => list(any())).called(1);

      expect(cubit.query.sort, 'popular');
      expect(cubit.query.attemptStatus, 'solved');
      expect(cubit.query.difficulty, 'hard');
    });

    test('null clears a filter rather than leaving it in place', () async {
      await cubit.setFilters(
        sort: 'recent',
        attemptStatus: 'solved',
        difficulty: 'hard',
      );
      expect(cubit.query.attemptStatus, 'solved');

      // `copyWith(attemptStatus: null)` alone would keep 'solved' — the `??`
      // fallback swallows the null. `setFilters` must pass the clear flag.
      await cubit.setFilters(sort: 'recent');

      expect(cubit.query.attemptStatus, isNull);
      expect(cubit.query.difficulty, isNull);
      expect(cubit.query.sort, 'recent');
    });

    test('clears one filter while keeping another', () async {
      await cubit.setFilters(
        sort: 'popular',
        attemptStatus: 'incorrect',
        difficulty: 'easy',
      );
      await cubit.setFilters(sort: 'popular', difficulty: 'easy');

      expect(cubit.query.attemptStatus, isNull);
      expect(cubit.query.difficulty, 'easy');
    });

    test('preserves the search term, which the sheet does not own', () async {
      await cubit.setSearch('arrays');
      await cubit.setFilters(sort: 'difficulty', difficulty: 'hard');

      expect(cubit.query.search, 'arrays');
    });

    test('always restarts from page 1', () async {
      await cubit.setFilters(sort: 'popular', difficulty: 'hard');

      // A filter change invalidates pagination; requesting a later page would
      // return a slice of a differently-filtered set.
      expect(capturedQueries().last.page, 1);
    });

    test('sends the filters the sheet chose, not a stale query', () async {
      await cubit.setFilters(sort: 'popular', attemptStatus: 'solved');
      await cubit.setFilters(sort: 'recent', difficulty: 'medium');

      final latest = capturedQueries().last;
      expect(latest.sort, 'recent');
      expect(latest.attemptStatus, isNull);
      expect(latest.difficulty, 'medium');
    });
  });

  group('badge count', () {
    test('defaults are not counted as active filters', () {
      const defaults = PracticeQueryParams();
      expect(defaults.sort, 'recent');
      expect(defaults.attemptStatus, isNull);
      expect(defaults.difficulty, isNull);
    });
  });
}
