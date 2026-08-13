import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/uploaded_file.dart';
import '../repositories/file_repository.dart';

/// Resolves an attachment uuid to its metadata.
class GetFileUseCase implements UseCase<UploadedFile, IdParams> {
  const GetFileUseCase(this._repository);

  final FileRepository _repository;

  @override
  Future<Either<Failure, UploadedFile>> call(IdParams params) =>
      _repository.getFile(params.id);
}

/// Resolves the URL a file can actually be opened with.
class ResolveFileUrlUseCase implements UseCase<String, UploadedFile> {
  const ResolveFileUrlUseCase(this._repository);

  final FileRepository _repository;

  @override
  Future<Either<Failure, String>> call(UploadedFile file) =>
      _repository.resolveOpenUrl(file);
}
