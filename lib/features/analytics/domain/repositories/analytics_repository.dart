import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/student_analytics.dart';

abstract class AnalyticsRepository {
  Future<Either<Failure, AnalyticsOverview>> getOverview();

  /// Null when the semester isn't in the student's batch/department.
  Future<Either<Failure, SemesterAnalytics?>> getSemester(String semesterId);
}
