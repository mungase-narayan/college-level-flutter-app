import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/contest_rating.dart';
import '../repositories/rating_repository.dart';

class GetMyRatingUseCase implements UseCase<ContestRating, NoParams> {
  const GetMyRatingUseCase(this._repository);

  final RatingRepository _repository;

  @override
  Future<Either<Failure, ContestRating>> call(NoParams params) =>
      _repository.getMyRating();
}
