import '../../domain/entities/course_tree.dart';

int _int(Object? value, [int fallback = 0]) => (value as num?)?.toInt() ?? fallback;

List<Map<String, dynamic>> _list(Object? value) =>
    (value as List?)?.whereType<Map<String, dynamic>>().toList(growable: false) ??
    const [];

/// JSON → [CourseTree], the payload of `GET /student/courses/:id/tree`.
///
/// The backend spreads the raw course/module/topic/material rows and layers a
/// `progress` object onto each level, so the models read those extra keys
/// alongside the schema columns.
class CourseTreeModel extends CourseTree {
  const CourseTreeModel({
    required super.id,
    required super.name,
    required super.code,
    required super.modules,
    required super.progress,
    super.description,
    super.credits,
    super.type,
    super.colorCode,
  });

  factory CourseTreeModel.fromJson(Map<String, dynamic> json) => CourseTreeModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        description: json['description'] as String?,
        credits: (json['credits'] as num?)?.toInt(),
        type: json['type'] as String?,
        colorCode: json['colorCode'] as String?,
        modules: _list(json['modules'])
            .map(CourseModuleModel.fromJson)
            .toList(growable: false),
        progress: CourseProgressModel.fromJson(json['progress']),
      );
}

class CourseModuleModel extends CourseModule {
  const CourseModuleModel({
    required super.id,
    required super.name,
    required super.order,
    required super.topics,
    required super.progress,
    super.description,
  });

  factory CourseModuleModel.fromJson(Map<String, dynamic> json) => CourseModuleModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        order: _int(json['order']),
        description: json['description'] as String?,
        topics: _list(json['topics'])
            .map(CourseTopicModel.fromJson)
            .toList(growable: false),
        progress: CourseProgressModel.fromJson(json['progress']),
      );
}

class CourseTopicModel extends CourseTopic {
  const CourseTopicModel({
    required super.id,
    required super.name,
    required super.order,
    required super.materials,
    required super.progress,
    super.description,
  });

  factory CourseTopicModel.fromJson(Map<String, dynamic> json) => CourseTopicModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        order: _int(json['order']),
        description: json['description'] as String?,
        materials: _list(json['materials'])
            .map(CourseMaterialModel.fromJson)
            .toList(growable: false),
        progress: CourseProgressModel.fromJson(json['progress']),
      );
}

class CourseMaterialModel extends CourseMaterial {
  const CourseMaterialModel({
    required super.id,
    required super.courseId,
    required super.name,
    required super.order,
    required super.completed,
    super.description,
    super.content,
    super.videoUrl,
    super.attachments,
    super.completedAt,
  });

  factory CourseMaterialModel.fromJson(Map<String, dynamic> json) =>
      CourseMaterialModel(
        id: json['id'] as String? ?? '',
        courseId: json['courseId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        order: _int(json['order']),
        completed: json['completed'] as bool? ?? false,
        completedAt: json['completedAt'] as String?,
        description: json['description'] as String?,
        content: json['content'] as String?,
        videoUrl: json['videoUrl'] as String?,
        attachments: (json['attachments'] as List?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const [],
      );
}

class CourseProgressModel extends CourseProgress {
  const CourseProgressModel({
    required super.totalMaterials,
    required super.completedMaterials,
    super.percent,
  });

  factory CourseProgressModel.fromJson(Object? value) {
    final json = value is Map<String, dynamic> ? value : const <String, dynamic>{};
    return CourseProgressModel(
      totalMaterials: _int(json['totalMaterials']),
      completedMaterials: _int(json['completedMaterials']),
      percent: (json['percent'] as num?)?.toInt(),
    );
  }
}
