import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/calendar_entry.dart';
import '../../domain/entities/calendar_view.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../datasources/calendar_service.dart';

class CalendarRepositoryImpl with RepositoryGuard implements CalendarRepository {
  const CalendarRepositoryImpl(this._service);

  final CalendarService _service;

  @override
  Future<Either<Failure, List<CalendarEntry>>> getCalendar({
    required CalendarRange range,
    required CalendarViewMode view,
  }) =>
      guard(() => _service.getCalendar(range: range, view: view));
}
