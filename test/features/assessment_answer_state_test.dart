import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/features/assessments/domain/entities/assessment_detail.dart';
import 'package:college_level/features/assessments/domain/entities/student_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

/// Selecting a different option used to leave the UI unchanged until the
/// student navigated away and back.
///
/// The cause was state equality, not the widget: answers lived in a mutable Map
/// *beside* the state, so editing one changed what the UI read without changing
/// the state's `props`. `emit` of a state equal to the current one is dropped by
/// bloc, so nothing repainted.
///
/// These tests pin the two halves of that: an unchanged state really is equal
/// (so re-emitting it is a no-op), and changing an answer really does produce
/// an unequal state (so the emit propagates).
AssessmentDetail _detail({List<QuestionAnswer> answers = const []}) =>
    AssessmentDetail(
      assessment: const StudentAssessment(
        id: 'a1',
        title: 'Test Quiz 01',
        category: 'quiz',
        type: 'questions',
        totalMarks: 13,
        resultsPublished: false,
      ),
      resultsPublished: false,
      questions: const [
        AssessmentQuestion(
          assessmentQuestionId: 'aq1',
          questionId: 'q1',
          title: 'f(x) = 3x - 2 at x = 5?',
          type: 'mcq',
          points: 1,
          options: [
            AnswerOption(id: 'a', text: '11'),
            AnswerOption(id: 'b', text: '13'),
          ],
        ),
      ],
      answers: answers,
    );

QuestionAnswer _answer(List<String> selected) => QuestionAnswer(
      assessmentQuestionId: 'aq1',
      questionId: 'q1',
      questionType: 'mcq',
      selectedAnswers: selected,
    );

void main() {
  group('RemoteState equality', () {
    test('re-emitting an unchanged state would be dropped by bloc', () {
      final detail = _detail();
      final before = RemoteState<AssessmentDetail>(
        status: RemoteStatus.success,
        data: detail,
      );

      // This is exactly what the buggy setAnswer emitted.
      final after = before.copyWith(status: RemoteStatus.success);

      expect(after, equals(before), reason: 'bloc drops equal states');
    });
  });

  group('AssessmentDetail.withAnswer', () {
    test('changing the selected option changes state equality', () {
      final before = RemoteState<AssessmentDetail>(
        status: RemoteStatus.success,
        data: _detail(answers: [_answer(const ['a'])]),
      );

      final after = RemoteState<AssessmentDetail>(
        status: RemoteStatus.success,
        data: before.data!.withAnswer(_answer(const ['b'])),
      );

      expect(after, isNot(equals(before)));
      expect(after.data!.answerFor('aq1')!.selectedAnswers, ['b']);
    });

    test('replaces the answer in place rather than appending a duplicate', () {
      final detail = _detail(answers: [_answer(const ['a'])])
          .withAnswer(_answer(const ['b']));

      expect(detail.answers, hasLength(1));
      expect(detail.answers.single.selectedAnswers, ['b']);
    });

    test('adds an answer for a question that had none', () {
      final detail = _detail().withAnswer(_answer(const ['a']));

      expect(detail.answers, hasLength(1));
      expect(detail.answersByQuestion.containsKey('aq1'), isTrue);
    });

    test('answeredCount tracks only questions with a selection', () {
      expect(_detail().answers.where((a) => a.isAnswered), isEmpty);

      final answered = _detail().withAnswer(_answer(const ['a']));
      expect(answered.answers.where((a) => a.isAnswered), hasLength(1));

      // Clearing the selection makes it unanswered again.
      final cleared = answered.withAnswer(_answer(const []));
      expect(cleared.answers.where((a) => a.isAnswered), isEmpty);
    });
  });
}
