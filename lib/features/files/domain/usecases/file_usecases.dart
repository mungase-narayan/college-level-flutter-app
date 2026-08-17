import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

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

/// Uploads a file picked on the device — an assignment attachment.
class UploadFileUseCase implements UseCase<UploadedFile, UploadFileParams> {
  const UploadFileUseCase(this._repository);

  final FileRepository _repository;

  @override
  Future<Either<Failure, UploadedFile>> call(UploadFileParams params) =>
      _repository.upload(
        filePath: params.filePath,
        fileName: params.fileName,
      );
}

class UploadFileParams extends Equatable {
  const UploadFileParams({required this.filePath, required this.fileName});

  /// A path on the device, as the picker reports it.
  final String filePath;

  /// The name to store it under — what the teacher will see.
  final String fileName;

  @override
  List<Object?> get props => [filePath, fileName];
}

/// Resolves the URL a file can actually be opened with.
class ResolveFileUrlUseCase implements UseCase<String, UploadedFile> {
  const ResolveFileUrlUseCase(this._repository);

  final FileRepository _repository;

  @override
  Future<Either<Failure, String>> call(UploadedFile file) =>
      _repository.resolveOpenUrl(file);
}
