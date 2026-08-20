import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../domain/entities/submission.dart';
import '../../domain/usecases/teacher_grading_usecases.dart';

/// The per-question rollup behind the Questions tab.
class StatisticsCubit extends Cubit<RemoteState<List<QuestionStat>>> {
  StatisticsCubit({
    required TeacherGradingUseCases grading,
    required this.assessmentId,
  })  : _grading = grading,
        super(const RemoteState());

  final TeacherGradingUseCases _grading;
  final String assessmentId;

  /// The questions the server could score. Coding and subjective ones report a
  /// null accuracy and are excluded from every average below.
  List<QuestionStat> get graded => [
        for (final stat in state.data ?? const <QuestionStat>[])
          if (stat.isAutoGraded) stat,
      ];

  int get questionCount => state.data?.length ?? 0;

  int? get averageAccuracy {
    final rows = graded;
    if (rows.isEmpty) return null;
    final sum = rows.fold<int>(0, (total, q) => total + (q.accuracy ?? 0));
    return (sum / rows.length).round();
  }

  int? get highestAccuracy {
    final rows = graded;
    if (rows.isEmpty) return null;
    return rows.map((q) => q.accuracy ?? 0).reduce((a, b) => a > b ? a : b);
  }

  int get needsGrading => questionCount - graded.length;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _grading.statistics(assessmentId);
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (stats) => emit(RemoteState(status: RemoteStatus.success, data: stats)),
    );
  }
}
