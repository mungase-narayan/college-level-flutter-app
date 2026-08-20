import '../../../../../core/utils/json_coerce.dart';
import '../../domain/entities/teacher_course_tree.dart';
import 'teacher_course_model.dart';

class TeacherCourseTreeModel extends TeacherCourseTree {
  const TeacherCourseTreeModel({
    required super.id,
    required super.name,
    required super.code,
    required super.type,
    required super.status,
    required super.credits,
    required super.modules,
    required super.instructors,
    super.description,
    super.colorCode,
  });

  factory TeacherCourseTreeModel.fromJson(Map<String, dynamic> json) =>
      TeacherCourseTreeModel(
        id: asString(json['id']),
        name: asString(json['name']),
        code: asString(json['code']),
        type: asString(json['type']),
        status: asString(json['status']),
        credits: asInt(json['credits']),
        description: asStringOrNull(json['description']),
        colorCode: asStringOrNull(json['colorCode']),
        modules: asObjectList(json['modules'])
            .map(TeacherModuleModel.fromJson)
            .toList(growable: false),
        instructors: asObjectList(json['instructors'])
            .map(CourseInstructorModel.fromJson)
            .toList(growable: false),
      );
}

class TeacherModuleModel extends TeacherModule {
  const TeacherModuleModel({
    required super.id,
    required super.courseId,
    required super.name,
    required super.order,
    required super.topics,
    required super.scope,
    super.description,
    super.createdBy,
  });

  factory TeacherModuleModel.fromJson(Map<String, dynamic> json) =>
      TeacherModuleModel(
        id: asString(json['id']),
        courseId: asString(json['courseId']),
        name: asString(json['name']),
        order: asInt(json['order']),
        description: asStringOrNull(json['description']),
        createdBy: asStringOrNull(json['createdBy']),
        scope: contentScopeFrom(json),
        topics: asObjectList(json['topics'])
            .map(TeacherTopicModel.fromJson)
            .toList(growable: false),
      );
}

class TeacherTopicModel extends TeacherTopic {
  const TeacherTopicModel({
    required super.id,
    required super.courseId,
    required super.courseModuleId,
    required super.name,
    required super.order,
    required super.materials,
    required super.scope,
    super.description,
    super.createdBy,
  });

  factory TeacherTopicModel.fromJson(Map<String, dynamic> json) =>
      TeacherTopicModel(
        id: asString(json['id']),
        courseId: asString(json['courseId']),
        courseModuleId: asString(json['courseModuleId']),
        name: asString(json['name']),
        order: asInt(json['order']),
        description: asStringOrNull(json['description']),
        createdBy: asStringOrNull(json['createdBy']),
        scope: contentScopeFrom(json),
        materials: asObjectList(json['materials'])
            .map(TeacherMaterialModel.fromJson)
            .toList(growable: false),
      );
}

class TeacherMaterialModel extends TeacherMaterial {
  const TeacherMaterialModel({
    required super.id,
    required super.courseId,
    required super.courseModuleId,
    required super.courseTopicId,
    required super.name,
    required super.order,
    required super.scope,
    super.description,
    super.content,
    super.videoUrl,
    super.attachments,
    super.createdBy,
  });

  factory TeacherMaterialModel.fromJson(Map<String, dynamic> json) =>
      TeacherMaterialModel(
        id: asString(json['id']),
        courseId: asString(json['courseId']),
        courseModuleId: asString(json['courseModuleId']),
        courseTopicId: asString(json['courseTopicId']),
        name: asString(json['name']),
        order: asInt(json['order']),
        description: asStringOrNull(json['description']),
        content: asStringOrNull(json['content']),
        videoUrl: asStringOrNull(json['videoUrl']),
        createdBy: asStringOrNull(json['createdBy']),
        scope: contentScopeFrom(json),
        attachments: asStringList(json['attachments']),
      );
}

class CourseInstructorModel extends CourseInstructor {
  const CourseInstructorModel({
    required super.id,
    required super.fullName,
    super.email,
    super.avatar,
    super.designation,
    super.division,
  });

  factory CourseInstructorModel.fromJson(Map<String, dynamic> json) {
    // The instructor's identity lives one level down, under `user`.
    final user = (json['user'] as Map<String, dynamic>?) ?? const {};
    final division = json['division'];

    return CourseInstructorModel(
      id: asString(json['id']),
      fullName: asStringOrNull(user['fullName']) ?? asStringOrNull(user['email']) ?? '',
      email: asStringOrNull(user['email']),
      avatar: asStringOrNull(user['avatar']),
      designation: asStringOrNull(json['designation']),
      division: division is Map<String, dynamic>
          ? CourseDivisionModel.fromJson(division)
          : null,
    );
  }
}

/// The `{divisionId, isGlobal, division, creator}` mixin every tree node carries.
///
/// `isGlobal` is trusted when present and otherwise derived from a null
/// `divisionId`, which is what actually defines school-wide content.
ContentScope contentScopeFrom(Map<String, dynamic> json) {
  final divisionId = asStringOrNull(json['divisionId']);
  final division = json['division'];
  final creator = json['creator'];

  return ContentScope(
    isGlobal: asBool(json['isGlobal'], orElse: divisionId == null),
    divisionId: divisionId,
    division: division is Map<String, dynamic>
        ? CourseDivisionModel.fromJson(division)
        : null,
    creator: creator is Map<String, dynamic>
        ? ContentCreator(
            id: asString(creator['id']),
            fullName: asStringOrNull(creator['fullName']),
          )
        : null,
  );
}
