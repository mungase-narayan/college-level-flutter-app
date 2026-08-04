import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/contest_rating.dart';

abstract class RatingRepository {
  Future<Either<Failure, ContestRating>> getMyRating();
}
