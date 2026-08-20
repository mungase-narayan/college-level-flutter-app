import '../../../../../core/common/widgets/heatmap_grid.dart';
import '../../domain/entities/daily_challenge.dart';
import '../../domain/entities/practice_attempt.dart';
import '../../domain/entities/practice_question.dart';
import '../../domain/entities/practice_summary.dart';

int _int(Object? value, [int fallback = 0]) => (value as num?)?.toInt() ?? fallback;
int? _intOrNull(Object? value) => (value as num?)?.toInt();
double? _doubleOrNull(Object? value) => (value as num?)?.toDouble();
Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};
List<Map<String, dynamic>> _maps(Object? value) =>
    (value as List?)?.whereType<Map<String, dynamic>>().toList(growable: false) ??
    const [];
List<String> _strings(Object? value) =>
    (value as List?)?.whereType<String>().toList(growable: false) ?? const [];

// ── Summary / analytics ─────────────────────────────────────────────────────

class PracticeSummaryModel extends PracticeSummary {
  const PracticeSummaryModel({
    required super.totalQuestionsAvailable,
    required super.questionsAttempted,
    required super.questionsSolved,
    required super.correctAnswers,
    required super.pendingReviews,
    required super.totalPoints,
    required super.practiceSeconds,
    super.overallAccuracy,
  });

  factory PracticeSummaryModel.fromJson(Map<String, dynamic> json) =>
      PracticeSummaryModel(
        totalQuestionsAvailable: _int(json['totalQuestionsAvailable']),
        questionsAttempted: _int(json['questionsAttempted']),
        questionsSolved: _int(json['questionsSolved']),
        correctAnswers: _int(json['correctAnswers']),
        pendingReviews: _int(json['pendingReviews']),
        totalPoints: _int(json['totalPoints']),
        practiceSeconds: _int(json['practiceSeconds']),
        overallAccuracy: _intOrNull(json['overallAccuracy']),
      );
}

class PracticeAnalyticsModel extends PracticeAnalytics {
  const PracticeAnalyticsModel({
    required super.overview,
    required super.heatmap,
    super.difficulty,
    super.subjects,
    super.daily,
    super.monthly,
    super.timeStats,
  });

  factory PracticeAnalyticsModel.fromJson(Map<String, dynamic> json) =>
      PracticeAnalyticsModel(
        overview: PracticeSummaryModel.fromJson(_map(json['overview'])),
        heatmap: ActivityHeatmapModel.fromJson(_map(json['heatmap'])),
        difficulty: _maps(json['difficulty'])
            .map((row) => _breakdown(row, 'difficulty'))
            .toList(growable: false),
        subjects: _maps(json['subjects'])
            .map((row) => _breakdown(row, 'name'))
            .toList(growable: false),
        daily: _maps(json['daily'])
            .map(
              (row) => PracticeDailyPoint(
                date: row['date'] as String? ?? '',
                attempts: _int(row['attempts']),
                correct: _int(row['correct']),
                points: _int(row['points']),
                accuracy: _intOrNull(row['accuracy']),
              ),
            )
            .toList(growable: false),
        monthly: _maps(json['monthly'])
            .map(
              (row) => PracticeMonthlyPoint(
                month: row['month'] as String? ?? '',
                solved: _int(row['solved']),
              ),
            )
            .toList(growable: false),
        timeStats: json['time'] == null ? null : _time(_map(json['time'])),
      );

  /// The two breakdowns label their key differently (`difficulty` vs `name`),
  /// so the caller says which one to read.
  static PracticeBreakdown _breakdown(Map<String, dynamic> json, String labelKey) =>
      PracticeBreakdown(
        label: json[labelKey] as String? ?? json['label'] as String? ?? '',
        attempts: _int(json['attempts']),
        solved: _int(json['solved']),
        accuracy: _intOrNull(json['accuracy']),
      );

  static PracticeTimeStats _time(Map<String, dynamic> json) => PracticeTimeStats(
        totalSeconds: _int(json['totalSeconds']),
        avgSecondsPerQuestion: _intOrNull(json['avgSecondsPerQuestion']),
        fastestSolveSec: _intOrNull(json['fastestSolveSec']),
        slowestSolveSec: _intOrNull(json['slowestSolveSec']),
      );
}

class ActivityHeatmapModel extends ActivityHeatmap {
  const ActivityHeatmapModel({required super.today, required super.days});

  factory ActivityHeatmapModel.fromJson(Map<String, dynamic> json) =>
      ActivityHeatmapModel(
        today: json['today'] as String? ?? '',
        days: _maps(json['days']).map(HeatmapDay.fromJson).toList(growable: false),
      );
}

// ── Questions ───────────────────────────────────────────────────────────────

class PracticeQuestionStatsModel extends PracticeQuestionStats {
  const PracticeQuestionStatsModel({
    required super.attempts,
    required super.correct,
    required super.attemptStatus,
    super.accuracy,
    super.bestScore,
    super.pendingReview,
    super.lastAttemptAt,
  });

  factory PracticeQuestionStatsModel.fromJson(Object? value) {
    final json = _map(value);
    return PracticeQuestionStatsModel(
      attempts: _int(json['attempts']),
      correct: _int(json['correct']),
      // The detail endpoint's stats object has no attemptStatus; derive it.
      attemptStatus: json['attemptStatus'] as String? ??
          (json['everCorrect'] == true
              ? 'solved'
              : _int(json['attempts']) > 0
                  ? 'attempted'
                  : 'not_attempted'),
      accuracy: _intOrNull(json['accuracy']),
      bestScore: _intOrNull(json['bestScore']),
      pendingReview: json['pendingReview'] as bool? ?? false,
      lastAttemptAt: json['lastAttemptAt'] as String?,
    );
  }
}

class PracticeQuestionListItemModel extends PracticeQuestionListItem {
  const PracticeQuestionListItemModel({
    required super.id,
    required super.title,
    required super.type,
    required super.difficulty,
    required super.points,
    required super.bookmarked,
    required super.stats,
    super.questionNumber,
    super.duration,
    super.tags,
    super.courseId,
    super.subject,
    super.moduleName,
    super.topicName,
    super.totalAttempts,
  });

  factory PracticeQuestionListItemModel.fromJson(Map<String, dynamic> json) =>
      PracticeQuestionListItemModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? 'mcq',
        difficulty: json['difficulty'] as String? ?? 'medium',
        points: _int(json['points'], 1),
        bookmarked: json['bookmarked'] as bool? ?? false,
        stats: PracticeQuestionStatsModel.fromJson(json['stats']),
        questionNumber: _intOrNull(json['questionNumber']),
        duration: _intOrNull(json['duration']),
        tags: _strings(json['tags']),
        courseId: json['courseId'] as String?,
        subject: json['subject'] as String?,
        moduleName: json['moduleName'] as String?,
        topicName: json['topicName'] as String?,
        totalAttempts: _int(json['totalAttempts']),
      );
}

class PracticeQuestionModel extends PracticeQuestion {
  const PracticeQuestionModel({
    required super.id,
    required super.title,
    required super.type,
    required super.difficulty,
    required super.points,
    super.description,
    super.duration,
    super.tags,
    super.attachments,
    super.options,
    super.answerType,
    super.constraints,
    super.examples,
    super.languageTemplates,
    super.moduleName,
    super.topicName,
    super.answers,
    super.explanation,
    super.modelAnswer,
    super.hints,
  });

  factory PracticeQuestionModel.fromJson(Map<String, dynamic> json) =>
      PracticeQuestionModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? 'mcq',
        difficulty: json['difficulty'] as String? ?? 'medium',
        points: _int(json['points'], 1),
        description: json['description'] as String?,
        duration: _intOrNull(json['duration']),
        tags: _strings(json['tags']),
        attachments: _strings(json['attachments']),
        options: _options(json['options']),
        answerType: json['answerType'] as String?,
        constraints: _strings(json['constraints']),
        examples: _maps(json['examples'])
            .map(
              (row) => QuestionExample(
                input: row['input'] as String?,
                output: row['output'] as String?,
                explanation: row['explanation'] as String?,
              ),
            )
            .toList(growable: false),
        languageTemplates: _templates(json['languageTemplates']),
        moduleName: json['moduleName'] as String?,
        topicName: json['topicName'] as String?,
        // Present only on the review payloads (`/attempts`, `/submit`); the
        // plain detail fetch sanitises all four away.
        answers: json['answers'] == null ? null : _strings(json['answers']),
        explanation: json['explanation'] as String?,
        modelAnswer: json['modelAnswer'] as String?,
        hints: _strings(json['hints']),
      );

  /// `options` is jsonb, so it may be a list of objects or — for a hand-authored
  /// question — a list of plain strings.
  static List<QuestionOption> _options(Object? value) {
    if (value is! List) return const [];
    final result = <QuestionOption>[];
    for (var index = 0; index < value.length; index++) {
      final entry = value[index];
      if (entry is Map) {
        result.add(
          QuestionOption(
            id: '${entry['id'] ?? entry['key'] ?? index}',
            text: '${entry['text'] ?? entry['label'] ?? entry['value'] ?? ''}',
          ),
        );
      } else if (entry is String) {
        result.add(QuestionOption(id: '$index', text: entry));
      }
    }
    return result;
  }

  /// `languageTemplates` is a **list** of template objects on the wire — this
  /// used to be read as a `{language: code}` map, which silently matched
  /// nothing and left every coding question without its starter code.
  ///
  /// A hand-authored question may still carry the map form, so both are
  /// accepted. `solutionCode` is present in the payload and deliberately not
  /// read: the backend does not strip it, and the student must not be handed
  /// the answer.
  static List<QuestionLanguageTemplate> _templates(Object? value) {
    if (value is List) {
      return [
        for (final entry in value.whereType<Map>())
          if ('${entry['language'] ?? ''}'.isNotEmpty)
            QuestionLanguageTemplate(
              language: '${entry['language']}',
              starterCode: entry['starterCode'] as String?,
              placeholderCode: entry['placeholderCode'] as String?,
            ),
      ];
    }
    if (value is Map) {
      return [
        for (final entry in value.entries)
          QuestionLanguageTemplate(
            language: '${entry.key}',
            starterCode: '${entry.value ?? ''}',
          ),
      ];
    }
    return const [];
  }
}

class PracticeQuestionDetailModel extends PracticeQuestionDetail {
  const PracticeQuestionDetailModel({
    required super.question,
    required super.stats,
    required super.bookmarked,
    super.sampleTestCases,
  });

  factory PracticeQuestionDetailModel.fromJson(Map<String, dynamic> json) =>
      PracticeQuestionDetailModel(
        question: PracticeQuestionModel.fromJson(_map(json['question'])),
        stats: PracticeQuestionStatsModel.fromJson(json['stats']),
        bookmarked: json['bookmarked'] as bool? ?? false,
        sampleTestCases: _maps(json['sampleTestCases'])
            .map(
              (row) => CodingSampleCase(
                id: row['id'] as String? ?? '',
                input: row['input'] as String?,
                output: row['output'] as String?,
                explanation: row['explanation'] as String?,
                order: _int(row['order']),
              ),
            )
            .toList(growable: false),
      );
}

// ── Attempts, runs and submissions ──────────────────────────────────────────

class PracticeAttemptModel extends PracticeAttempt {
  const PracticeAttemptModel({
    required super.id,
    required super.questionId,
    required super.questionType,
    required super.attempt,
    required super.status,
    super.isCorrect,
    super.score,
    super.maxScore,
    super.pointsAwarded,
    super.selectedAnswers,
    super.answerText,
    super.attachments,
    super.code,
    super.language,
    super.studentNote,
    super.feedback,
    super.codingResult,
    super.timeTakenSec,
    super.submittedAt,
  });

  factory PracticeAttemptModel.fromJson(Map<String, dynamic> json) =>
      PracticeAttemptModel(
        id: json['id'] as String? ?? '',
        questionId: json['questionId'] as String? ?? '',
        questionType: json['questionType'] as String? ?? 'mcq',
        attempt: _int(json['attempt'], 1),
        status: json['status'] as String? ?? 'evaluated',
        // Null is meaningful: an attempt awaiting review is not a wrong one.
        isCorrect: json['isCorrect'] as bool?,
        score: _intOrNull(json['score']),
        maxScore: _intOrNull(json['maxScore']),
        pointsAwarded: _int(json['pointsAwarded']),
        selectedAnswers: _strings(json['selectedAnswers']),
        answerText: json['answerText'] as String?,
        attachments: _strings(json['attachments']),
        code: json['code'] as String?,
        language: json['language'] as String?,
        studentNote: json['studentNote'] as String?,
        feedback: json['feedback'] as String?,
        codingResult: json['codingResult'] == null
            ? null
            : codingResultFromJson(_map(json['codingResult'])),
        timeTakenSec: _intOrNull(json['timeTakenSec']),
        submittedAt: json['submittedAt'] as String?,
      );
}

PracticeCodingResult codingResultFromJson(Map<String, dynamic> json) =>
    PracticeCodingResult(
      passed: _int(json['passed']),
      total: _int(json['total']),
      compileError: json['compileError'] as bool? ?? false,
      allPassed: json['allPassed'] as bool? ?? false,
      failureReason: json['failureReason'] as String?,
      cases: _maps(json['cases'])
          .map(
            (row) => PracticeCaseResult(
              testCaseId: row['testCaseId'] as String? ?? '',
              status: row['status'] as String? ?? 'Unknown',
              passed: row['passed'] as bool? ?? false,
              isSample: row['isSample'] as bool? ?? false,
              timeSec: _doubleOrNull(row['timeSec']),
              memoryKb: _intOrNull(row['memoryKb']),
              // Populated for sample cases only; a hidden case reports nothing
              // but its verdict.
              stdin: row['stdin'] as String?,
              stdout: row['stdout'] as String?,
              stderr: row['stderr'] as String?,
              expectedOutput: row['expectedOutput'] as String?,
            ),
          )
          .toList(growable: false),
    );

PracticeCustomRunResult customRunFromJson(Map<String, dynamic> json) =>
    PracticeCustomRunResult(
      status: json['status'] as String? ?? 'Unknown',
      compileError: json['compileError'] as bool? ?? false,
      stdout: json['stdout'] as String?,
      stderr: json['stderr'] as String?,
      timeSec: _doubleOrNull(json['timeSec']),
      memoryKb: _intOrNull(json['memoryKb']),
    );

PracticeAttemptHistory attemptHistoryFromJson(Map<String, dynamic> json) =>
    PracticeAttemptHistory(
      question: PracticeQuestionModel.fromJson(_map(json['question'])),
      attempts: _maps(json['attempts'])
          .map(PracticeAttemptModel.fromJson)
          .toList(growable: false),
    );

PracticeSubmitResult submitResultFromJson(Map<String, dynamic> json) =>
    PracticeSubmitResult(
      attempt: PracticeAttemptModel.fromJson(_map(json['submission'])),
      question: PracticeQuestionModel.fromJson(_map(json['question'])),
    );

PracticeFilterOptions filterOptionsFromJson(Map<String, dynamic> json) =>
    PracticeFilterOptions(
      subjects: _maps(json['subjects'])
          .map(
            (row) => PracticeSubject(
              id: row['id'] as String? ?? '',
              name: row['name'] as String? ?? '',
              code: row['code'] as String? ?? '',
            ),
          )
          .toList(growable: false),
      modules: _strings(json['modules']),
      topics: _strings(json['topics']),
    );

// ── Daily challenge ─────────────────────────────────────────────────────────

DailyCalendar dailyCalendarFromJson(Map<String, dynamic> json) => DailyCalendar(
      month: json['month'] as String? ?? '',
      days: _maps(json['days'])
          .map(DailyChallengeDayModel.fromJson)
          .toList(growable: false),
      summary: _calendarSummary(_map(json['summary'])),
    );

DailyCalendarSummary _calendarSummary(Map<String, dynamic> json) =>
    DailyCalendarSummary(
      daysInMonth: _int(json['daysInMonth']),
      postedCount: _int(json['postedCount']),
      completedCount: _int(json['completedCount']),
      perfect: json['perfect'] as bool? ?? false,
      isClosed: json['isClosed'] as bool? ?? false,
    );

DailyChallengeSubmitResult dailySubmitResultFromJson(Map<String, dynamic> json) =>
    DailyChallengeSubmitResult(
      attempt: PracticeAttemptModel.fromJson(_map(json['submission'])),
      question: PracticeQuestionModel.fromJson(_map(json['question'])),
      completion: json['completion'] == null
          ? null
          : DailyChallengeModel.completionFromJson(_map(json['completion'])),
    );

class DailyChallengeModel extends DailyChallenge {
  const DailyChallengeModel({
    required super.available,
    required super.isOpen,
    required super.streak,
    super.set,
    super.questions,
    super.completion,
    super.availableTickets,
    super.timeTravelUnlocked,
  });

  factory DailyChallengeModel.fromJson(Map<String, dynamic> json) =>
      DailyChallengeModel(
        available: json['available'] as bool? ?? false,
        isOpen: json['isOpen'] as bool? ?? false,
        streak: _streak(json['streak']),
        set: json['set'] == null ? null : _set(_map(json['set'])),
        questions: _maps(json['questions'])
            .map(PracticeQuestionModel.fromJson)
            .toList(growable: false),
        completion:
            json['completion'] == null
                ? null
                : completionFromJson(_map(json['completion'])),
        availableTickets: _int(json['availableTickets']),
        timeTravelUnlocked: json['timeTravelUnlocked'] as bool? ?? false,
      );

  static DailyStreak _streak(Object? value) {
    final json = _map(value);
    return DailyStreak(
      currentStreak: _int(json['currentStreak']),
      totalPoints: _int(json['totalPoints']),
      challengesCompleted: _int(json['challengesCompleted']),
    );
  }

  static DailyChallengeSet _set(Map<String, dynamic> json) => DailyChallengeSet(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        date: json['date'] as String? ?? '',
        totalQuestions: _int(json['totalQuestions']),
        availableFrom: json['availableFrom'] as String?,
        availableUntil: json['availableUntil'] as String?,
        status: json['status'] as String?,
      );

  static DailyChallengeCompletion completionFromJson(Map<String, dynamic> json) =>
      DailyChallengeCompletion(
        status: json['status'] as String? ?? 'in_progress',
        totalQuestions: _int(json['totalQuestions']),
        pointsEarned: _int(json['pointsEarned']),
        solvedQuestionIds: _strings(json['solvedQuestionIds']),
        attemptedQuestionIds: _strings(json['attemptedQuestionIds']),
        completedAt: json['completedAt'] as String?,
      );
}

class DailyChallengeDayModel extends DailyChallengeDay {
  const DailyChallengeDayModel({
    required super.date,
    required super.setId,
    required super.title,
    required super.totalQuestions,
    required super.status,
    required super.solvedCount,
    super.attemptedCount,
  });

  factory DailyChallengeDayModel.fromJson(Map<String, dynamic> json) =>
      DailyChallengeDayModel(
        date: json['date'] as String? ?? '',
        setId: json['setId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        totalQuestions: _int(json['totalQuestions']),
        status: json['status'] as String? ?? 'upcoming',
        solvedCount: _int(json['solvedCount']),
        attemptedCount: _int(json['attemptedCount']),
      );
}
