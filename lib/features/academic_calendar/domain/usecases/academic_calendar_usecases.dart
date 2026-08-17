import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/academic_calendar.dart';
import '../repositories/academic_calendar_repository.dart';

class GetMyAcademicCalendarUseCase
    implements UseCase<AcademicCalendar?, NoParams> {
  const GetMyAcademicCalendarUseCase(this._repository);

  final AcademicCalendarRepository _repository;

  @override
  Future<Either<Failure, AcademicCalendar?>> call(NoParams params) =>
      _repository.getMyCalendar();
}
