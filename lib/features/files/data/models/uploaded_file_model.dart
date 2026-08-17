import '../../domain/entities/uploaded_file.dart';

/// JSON → [UploadedFile], the payload of `GET /files/:id`.
class UploadedFileModel extends UploadedFile {
  const UploadedFileModel({
    required super.id,
    required super.originalName,
    required super.fileUrl,
    required super.contentType,
    required super.category,
    required super.isPublic,
    super.fileName,
    super.fileExtension,
    super.fileSize,
  });

  factory UploadedFileModel.fromJson(Map<String, dynamic> json) =>
      UploadedFileModel(
        id: json['id'] as String? ?? '',
        originalName: json['originalName'] as String? ?? '',
        fileUrl: json['fileUrl'] as String? ?? '',
        contentType: json['contentType'] as String? ?? '',
        category: FileCategory.parse(json['fileCategory'] as String?),
        // Absent reads as private, which is the safer default: it only means an
        // extra presigned-URL round trip, never a broken link.
        isPublic: json['isPublic'] as bool? ?? false,
        fileName: json['fileName'] as String?,
        fileExtension: json['fileExtension'] as String?,
        fileSize: (json['fileSize'] as num?)?.toInt(),
      );
}
