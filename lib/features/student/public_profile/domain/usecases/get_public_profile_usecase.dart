import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/public_profile.dart';
import '../repositories/public_profile_repository.dart';

class GetPublicProfileUseCase implements UseCase<PublicProfile, String> {
  const GetPublicProfileUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Either<Failure, PublicProfile>> call(String username) =>
      _repository.getPublicProfile(username);
}
