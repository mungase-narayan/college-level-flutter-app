import '../../../../../core/utils/json_coerce.dart';
import '../../domain/entities/bank_question.dart';

class BankQuestionModel extends BankQuestion {
  const BankQuestionModel({
    required super.id,
    required super.title,
    required super.type,
    required super.difficulty,
    required super.category,
    required super.points,
    super.questionNumber,
    super.duration,
    super.tags,
    super.moduleName,
    super.topicName,
  });

  factory BankQuestionModel.fromJson(Map<String, dynamic> json) =>
      BankQuestionModel(
        id: asString(json['id']),
        title: asString(json['title']),
        type: asString(json['type']),
        difficulty: asString(json['difficulty']),
        category: asString(json['category']),
        points: asInt(json['points']),
        questionNumber: asIntOrNull(json['questionNumber']),
        duration: asIntOrNull(json['duration']),
        tags: asStringList(json['tags']),
        moduleName: asStringOrNull(json['moduleName']),
        topicName: asStringOrNull(json['topicName']),
      );
}
