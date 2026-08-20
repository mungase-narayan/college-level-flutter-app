import 'package:equatable/equatable.dart';

/// One pickable question, from either source the picker reads.
///
/// In edit mode the rows come from `GET /assessments/:id/questions/bank`, which
/// already excludes what is attached. While creating there is no assessment id
/// yet, so they come from `GET /teacher/questions?status=active` instead — that
/// endpoint excludes nothing, so the picker dedupes against its own basket.
/// The two payloads carry the same fields, so one entity serves both.
class BankQuestion extends Equatable {
  const BankQuestion({
    required this.id,
    required this.title,
    required this.type,
    required this.difficulty,
    required this.category,
    required this.points,
    this.questionNumber,
    this.duration,
    this.tags = const [],
    this.moduleName,
    this.topicName,
  });

  final String id;
  final String title;
  final String type;
  final String difficulty;
  final String category;

  /// What attaching this question adds to the assessment's derived total.
  final int points;

  final int? questionNumber;
  final int? duration;
  final List<String> tags;
  final String? moduleName;
  final String? topicName;

  /// Module › Topic, for the one line of provenance the row shows.
  String? get placement {
    final parts = [moduleName, topicName].whereType<String>().where(
          (part) => part.trim().isNotEmpty,
        );
    return parts.isEmpty ? null : parts.join(' › ');
  }

  @override
  List<Object?> get props => [id, title, type, difficulty, category, points];
}
