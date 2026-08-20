import 'package:equatable/equatable.dart';

import 'teacher_course.dart';

/// `GET /teacher/courses/:id/tree?divisionId=` — the course with its
/// module → topic → material hierarchy for one section.
///
/// The student tree of the same name is progress-shaped (`completed`, percent
/// counts); this one is authoring-shaped. Every node carries a [ContentScope]
/// saying who owns it and whether the teacher may touch it.
class TeacherCourseTree extends Equatable {
  const TeacherCourseTree({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.status,
    required this.credits,
    required this.modules,
    required this.instructors,
    this.description,
    this.colorCode,
  });

  final String id;
  final String name;
  final String code;
  final String type;
  final String status;
  final int credits;
  final List<TeacherModule> modules;

  /// Every division's instructors, not just the selected section's.
  final List<CourseInstructor> instructors;
  final String? description;
  final String? colorCode;

  int get totalTopics =>
      modules.fold(0, (sum, module) => sum + module.topics.length);

  int get totalMaterials => modules.fold(
        0,
        (sum, module) =>
            sum +
            module.topics.fold(0, (inner, topic) => inner + topic.materials.length),
      );

  /// Finds a material and the module/topic it sits under.
  ///
  /// The material screen holds only an id and re-derives the rest from the
  /// current tree, so an edit that refetches shows through with no state to
  /// keep in sync — the same trick the student tree uses.
  TeacherMaterialLocation? locate(String materialId) {
    for (final module in modules) {
      for (final topic in module.topics) {
        for (final material in topic.materials) {
          if (material.id == materialId) {
            return TeacherMaterialLocation(
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
  List<Object?> get props => [id, name, code, type, status, credits, modules];
}

class TeacherMaterialLocation extends Equatable {
  const TeacherMaterialLocation({
    required this.module,
    required this.topic,
    required this.material,
  });

  final TeacherModule module;
  final TeacherTopic topic;
  final TeacherMaterial material;

  @override
  List<Object?> get props => [module, topic, material];
}

/// Who owns a node, and therefore what the teacher may do to it.
///
/// `divisionId == null` means the admin authored it school-wide: every division
/// inherits it and no teacher may edit or delete it (the server answers 403
/// `COURSE_CONTENT_READ_ONLY`). Teachers extend such content by adding their own
/// section-scoped children *inside* it, which is always allowed.
class ContentScope extends Equatable {
  const ContentScope({
    required this.isGlobal,
    this.divisionId,
    this.division,
    this.creator,
  });

  final bool isGlobal;
  final String? divisionId;
  final CourseDivision? division;
  final ContentCreator? creator;

  @override
  List<Object?> get props => [isGlobal, divisionId, division, creator];
}

class ContentCreator extends Equatable {
  const ContentCreator({required this.id, this.fullName});

  final String id;
  final String? fullName;

  @override
  List<Object?> get props => [id, fullName];
}

/// The behaviour every tree node shares.
mixin TeacherContentNode {
  String get id;
  String get name;
  String? get description;
  int get order;
  String? get createdBy;
  ContentScope get scope;

  bool get isGlobal => scope.isGlobal;

  /// Whether this teacher may edit or delete this row.
  ///
  /// Two gates: school-wide content is read-only to everyone, and beyond that
  /// only the author may act. The **author rule is client-side only** — the API
  /// lets any teacher of the division mutate — but the web enforces it, so a
  /// co-teacher sees another teacher's content read-only and the port matches.
  bool canManage(String currentUserId) =>
      !isGlobal && createdBy != null && createdBy == currentUserId;
}

class TeacherModule extends Equatable with TeacherContentNode {
  const TeacherModule({
    required this.id,
    required this.courseId,
    required this.name,
    required this.order,
    required this.topics,
    required this.scope,
    this.description,
    this.createdBy,
  });

  @override
  final String id;
  final String courseId;
  @override
  final String name;
  @override
  final int order;
  final List<TeacherTopic> topics;
  @override
  final ContentScope scope;
  @override
  final String? description;
  @override
  final String? createdBy;

  @override
  List<Object?> get props => [id, name, order, topics, scope, description];
}

class TeacherTopic extends Equatable with TeacherContentNode {
  const TeacherTopic({
    required this.id,
    required this.courseId,
    required this.courseModuleId,
    required this.name,
    required this.order,
    required this.materials,
    required this.scope,
    this.description,
    this.createdBy,
  });

  @override
  final String id;
  final String courseId;
  final String courseModuleId;
  @override
  final String name;
  @override
  final int order;
  final List<TeacherMaterial> materials;
  @override
  final ContentScope scope;
  @override
  final String? description;
  @override
  final String? createdBy;

  @override
  List<Object?> get props => [id, name, order, materials, scope, description];
}

class TeacherMaterial extends Equatable with TeacherContentNode {
  const TeacherMaterial({
    required this.id,
    required this.courseId,
    required this.courseModuleId,
    required this.courseTopicId,
    required this.name,
    required this.order,
    required this.scope,
    this.description,
    this.content,
    this.videoUrl,
    this.attachments = const [],
    this.createdBy,
  });

  @override
  final String id;
  final String courseId;
  final String courseModuleId;
  final String courseTopicId;
  @override
  final String name;
  @override
  final int order;
  @override
  final ContentScope scope;
  @override
  final String? description;

  /// Markdown body.
  final String? content;
  final String? videoUrl;

  /// File uuids — resolve through `GET /files/:id` to display or download.
  final List<String> attachments;
  @override
  final String? createdBy;

  /// Drives the icon in the tree: video, attachment, or plain reading.
  TeacherMaterialKind get kind {
    if ((videoUrl ?? '').isNotEmpty) return TeacherMaterialKind.video;
    if (attachments.isNotEmpty) return TeacherMaterialKind.file;
    return TeacherMaterialKind.reading;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        order,
        scope,
        description,
        content,
        videoUrl,
        attachments,
      ];
}

enum TeacherMaterialKind { video, file, reading }

/// An instructor row on the course tree, one per (teacher, division).
class CourseInstructor extends Equatable {
  const CourseInstructor({
    required this.id,
    required this.fullName,
    this.email,
    this.avatar,
    this.designation,
    this.division,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? avatar;
  final String? designation;
  final CourseDivision? division;

  /// `designation · email`, dropping whichever is missing.
  String? get subtitle {
    final parts = [
      if ((designation ?? '').isNotEmpty) designation!,
      if ((email ?? '').isNotEmpty) email!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  List<Object?> get props => [id, fullName, email, avatar, designation, division];
}
