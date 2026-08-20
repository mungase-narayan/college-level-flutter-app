import 'package:equatable/equatable.dart';

/// `GET /student/courses/:id/tree` — the course with its module → topic →
/// material hierarchy, scoped to the student's division, with per-level
/// completion progress folded in.
class CourseTree extends Equatable {
  const CourseTree({
    required this.id,
    required this.name,
    required this.code,
    required this.modules,
    required this.progress,
    this.description,
    this.credits,
    this.type,
    this.colorCode,
  });

  final String id;
  final String name;
  final String code;
  final List<CourseModule> modules;
  final CourseProgress progress;
  final String? description;
  final int? credits;
  final String? type;
  final String? colorCode;

  int get totalTopics =>
      modules.fold(0, (sum, module) => sum + module.topics.length);

  /// Finds a material and the module/topic it sits under.
  ///
  /// The material page holds only an id and re-derives the rest from the
  /// current tree on every build, so a completion toggle that refetches shows
  /// through without any state to keep in sync. This is the port of
  /// `findSelected()` in `student/courses/detail/learning-plan/index.tsx`.
  MaterialLocation? locate(String materialId) {
    for (final module in modules) {
      for (final topic in module.topics) {
        for (final material in topic.materials) {
          if (material.id == materialId) {
            return MaterialLocation(
              module: module,
              topic: topic,
              material: material,
            );
          }
        }
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [id, name, code, modules, progress];
}

/// A material together with where it sits in the tree.
class MaterialLocation extends Equatable {
  const MaterialLocation({
    required this.module,
    required this.topic,
    required this.material,
  });

  final CourseModule module;
  final CourseTopic topic;
  final CourseMaterial material;

  @override
  List<Object?> get props => [module, topic, material];
}

class CourseModule extends Equatable {
  const CourseModule({
    required this.id,
    required this.name,
    required this.order,
    required this.topics,
    required this.progress,
    this.description,
  });

  final String id;
  final String name;
  final int order;
  final List<CourseTopic> topics;
  final CourseProgress progress;
  final String? description;

  @override
  List<Object?> get props => [id, name, order, topics, progress, description];
}

class CourseTopic extends Equatable {
  const CourseTopic({
    required this.id,
    required this.name,
    required this.order,
    required this.materials,
    required this.progress,
    this.description,
  });

  final String id;
  final String name;
  final int order;
  final List<CourseMaterial> materials;
  final CourseProgress progress;
  final String? description;

  @override
  List<Object?> get props => [id, name, order, materials, progress, description];
}

class CourseMaterial extends Equatable {
  const CourseMaterial({
    required this.id,
    required this.courseId,
    required this.name,
    required this.order,
    required this.completed,
    this.description,
    this.content,
    this.videoUrl,
    this.attachments = const [],
    this.completedAt,
  });

  final String id;
  final String courseId;
  final String name;
  final int order;
  final bool completed;
  final String? description;

  /// Markdown body shown in the material viewer.
  final String? content;
  final String? videoUrl;

  /// File uuids — resolve through `GET /files/:id` to display or download.
  final List<String> attachments;
  final String? completedAt;

  /// Drives the icon in the tree: video, attachment, or plain reading.
  MaterialKind get kind {
    if ((videoUrl ?? '').isNotEmpty) return MaterialKind.video;
    if (attachments.isNotEmpty) return MaterialKind.file;
    return MaterialKind.reading;
  }

  CourseMaterial copyWith({bool? completed, String? completedAt}) => CourseMaterial(
        id: id,
        courseId: courseId,
        name: name,
        order: order,
        completed: completed ?? this.completed,
        description: description,
        content: content,
        videoUrl: videoUrl,
        attachments: attachments,
        completedAt: completedAt ?? this.completedAt,
      );

  @override
  List<Object?> get props => [
        id,
        courseId,
        name,
        order,
        completed,
        description,
        content,
        videoUrl,
        attachments,
        completedAt,
      ];
}

enum MaterialKind { video, file, reading }

/// Completion counts, present at course, module, and topic level. Only the
/// course level carries `percent`.
class CourseProgress extends Equatable {
  const CourseProgress({
    required this.totalMaterials,
    required this.completedMaterials,
    this.percent,
  });

  final int totalMaterials;
  final int completedMaterials;
  final int? percent;

  /// 0–1, for progress bars. Falls back to computing from the counts when the
  /// level doesn't send `percent`.
  double get fraction {
    if (totalMaterials == 0) return 0;
    return (percent != null ? percent! / 100 : completedMaterials / totalMaterials)
        .clamp(0.0, 1.0);
  }

  int get percentValue => percent ?? (fraction * 100).round();

  @override
  List<Object?> get props => [totalMaterials, completedMaterials, percent];
}
