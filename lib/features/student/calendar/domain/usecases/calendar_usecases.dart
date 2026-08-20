import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/calendar_entry.dart';
import '../entities/calendar_view.dart';
import '../repositories/calendar_repository.dart';

class GetCalendarUseCase
    implements UseCase<List<CalendarEntry>, CalendarQueryParams> {
  const GetCalendarUseCase(this._repository);

  final CalendarRepository _repository;

  @override
  Future<Either<Failure, List<CalendarEntry>>> call(
    CalendarQueryParams params,
  ) =>
      _repository.getCalendar(range: params.range, view: params.view);
}

class CalendarQueryParams extends Equatable {
  const CalendarQueryParams({required this.range, required this.view});

  /// Builds the window the given view needs around [date].
  factory CalendarQueryParams.of(CalendarViewMode view, DateTime date) =>
      CalendarQueryParams(range: CalendarDates.rangeFor(view, date), view: view);

  final CalendarRange range;
  final CalendarViewMode view;

  @override
  List<Object?> get props => [range, view];
}
