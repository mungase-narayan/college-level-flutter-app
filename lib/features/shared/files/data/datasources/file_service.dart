import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/dio_client.dart';
import '../models/uploaded_file_model.dart';

/// Raw HTTP for the file endpoints — the port of `src/api/file`.
class FileService {
  const FileService(this._client);

  final DioClient _client;

  /// `GET /files/:id` — the file's metadata, including its name and category.
  Future<UploadedFileModel> getFile(String fileId) async {
    final response = await _client.get(
      ApiUrls.file(fileId),
      parse: (data) =>
          UploadedFileModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `POST /files/upload` — hands the bytes over and gets a file record back.
  ///
  /// Every endpoint that *uses* a file takes the returned uuid, never the bytes
  /// again, so what callers actually want from this is [UploadedFile.id].
  ///
  /// `isPublic: true` matches what the web sends for assignment attachments; a
  /// student's upload and a teacher's therefore behave identically when either
  /// side opens it.
  Future<UploadedFileModel> upload({
    required String filePath,
    required String fileName,
  }) async {
    final response = await _client.uploadFile(
      filePath: filePath,
      fileName: fileName,
      isPublic: true,
      parse: (data) =>
          UploadedFileModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `POST /files/upload-multiple` — several files in one request.
  ///
  /// One round trip instead of N, which also makes the batch succeed or fail
  /// as a unit rather than leaving a material half-attached.
  Future<List<UploadedFileModel>> uploadMany(
    List<({String path, String name})> files,
  ) async {
    final response = await _client.uploadFiles(
      files: files,
      isPublic: true,
      parse: (data) => (data as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(UploadedFileModel.fromJson)
              .toList(growable: false) ??
          const <UploadedFileModel>[],
    );
    return response.data;
  }

  /// `GET /files/:id/presigned-url` — a short-lived URL for a private file.
  ///
  /// This is what makes an attachment openable at all: every `/files/*` route
  /// is behind `verifyJWT`, and handing a bare API URL to the OS browser sends
  /// no `Authorization` header.
  Future<String> getPresignedUrl(String fileId) async {
    final response = await _client.get(
      ApiUrls.filePresignedUrl(fileId),
      parse: (data) {
        // The endpoint has been seen returning both a bare string and an
        // object, so both are accepted rather than guessing.
        if (data is String) return data;
        final json = (data as Map<String, dynamic>?) ?? const {};
        return (json['url'] ?? json['presignedUrl'] ?? json['fileUrl'] ?? '')
            as String;
      },
    );
    return response.data;
  }
}
