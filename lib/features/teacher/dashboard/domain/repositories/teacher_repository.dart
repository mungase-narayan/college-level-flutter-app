import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/teacher_dashboard.dart';

abstract class TeacherRepository {
  Future<Either<Failure, TeacherDashboard>> getDashboard();
}
