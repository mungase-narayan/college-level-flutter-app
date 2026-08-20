import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/uploaded_file.dart';
import '../../domain/repositories/file_repository.dart';
import '../datasources/file_service.dart';

class FileRepositoryImpl with RepositoryGuard implements FileRepository {
  const FileRepositoryImpl(this._service);

  final FileService _service;

  @override
  Future<Either<Failure, UploadedFile>> getFile(String fileId) =>
      guard(() => _service.getFile(fileId));

  @override
  Future<Either<Failure, List<UploadedFile>>> uploadMany(
    List<({String path, String name})> files,
  ) =>
      guard(() => _service.uploadMany(files));

  @override
  Future<Either<Failure, UploadedFile>> upload({
    required String filePath,
    required String fileName,
  }) =>
      guard(() => _service.upload(filePath: filePath, fileName: fileName));

  @override
  Future<Either<Failure, String>> resolveOpenUrl(UploadedFile file) =>
      guard(() async {
        // A public object is served straight from the bucket, so the extra
        // round trip is only spent when it actually buys something.
        if (file.isPublic && file.fileUrl.isNotEmpty) return file.fileUrl;

        final presigned = await _service.getPresignedUrl(file.id);
        return presigned.isNotEmpty ? presigned : file.fileUrl;
      });
}
