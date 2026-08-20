import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/calendar_entry.dart';
import '../entities/calendar_view.dart';

abstract class CalendarRepository {
  Future<Either<Failure, List<CalendarEntry>>> getCalendar({
    required CalendarRange range,
    required CalendarViewMode view,
  });
}
