import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/academic_calendar.dart';
import '../../domain/repositories/academic_calendar_repository.dart';
import '../datasources/academic_calendar_service.dart';

class AcademicCalendarRepositoryImpl
    with RepositoryGuard
    implements AcademicCalendarRepository {
  const AcademicCalendarRepositoryImpl(this._service);

  final AcademicCalendarService _service;

  @override
  Future<Either<Failure, AcademicCalendar?>> getMyCalendar() =>
      guard(_service.getMyCalendar);
}
