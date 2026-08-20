import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/student_analytics.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../datasources/analytics_service.dart';

class AnalyticsRepositoryImpl with RepositoryGuard implements AnalyticsRepository {
  const AnalyticsRepositoryImpl(this._service);

  final AnalyticsService _service;

  @override
  Future<Either<Failure, AnalyticsOverview>> getOverview() =>
      guard(() => _service.getOverview());

  @override
  Future<Either<Failure, SemesterAnalytics?>> getSemester(String semesterId) =>
      guard(() => _service.getSemester(semesterId));
}
