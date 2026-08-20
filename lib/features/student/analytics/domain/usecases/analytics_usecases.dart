import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/student_analytics.dart';
import '../repositories/analytics_repository.dart';

class GetAnalyticsOverviewUseCase implements UseCase<AnalyticsOverview, NoParams> {
  const GetAnalyticsOverviewUseCase(this._repository);

  final AnalyticsRepository _repository;

  @override
  Future<Either<Failure, AnalyticsOverview>> call(NoParams params) =>
      _repository.getOverview();
}

class GetSemesterAnalyticsUseCase implements UseCase<SemesterAnalytics?, IdParams> {
  const GetSemesterAnalyticsUseCase(this._repository);

  final AnalyticsRepository _repository;

  @override
  Future<Either<Failure, SemesterAnalytics?>> call(IdParams params) =>
      _repository.getSemester(params.id);
}
