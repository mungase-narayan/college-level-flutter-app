import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/academic_calendar.dart';

abstract class AcademicCalendarRepository {
  /// `Right(null)` means "nothing published" — a successful answer, not a
  /// failure. Only a transport or server error becomes a [Failure].
  Future<Either<Failure, AcademicCalendar?>> getMyCalendar();
}
