import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/teacher_dashboard.dart';
import '../repositories/teacher_repository.dart';

class GetTeacherDashboardUseCase
    implements UseCase<TeacherDashboard, NoParams> {
  const GetTeacherDashboardUseCase(this._repository);

  final TeacherRepository _repository;

  @override
  Future<Either<Failure, TeacherDashboard>> call(NoParams params) =>
      _repository.getDashboard();
}
