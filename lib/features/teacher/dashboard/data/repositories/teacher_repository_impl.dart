import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/teacher_dashboard.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../datasources/teacher_service.dart';

class TeacherRepositoryImpl with RepositoryGuard implements TeacherRepository {
  const TeacherRepositoryImpl(this._service);

  final TeacherService _service;

  @override
  Future<Either<Failure, TeacherDashboard>> getDashboard() =>
      guard(() => _service.getDashboard());
}
