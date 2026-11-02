import 'dart:convert';
import '../../../core/network/json.dart';

const quizLabels = ['A', 'B', 'C', 'D'];

class QuizQuestion {
  const QuizQuestion({
    required this.key,
    this.id,
    required this.prompt,
    required this.options,
    this.correct,
    this.position = 0,
  });
  final String key, prompt;
  final int position;
  final String? id, correct;
  final Map<String, String> options;
  factory QuizQuestion.empty(String key) => QuizQuestion(
    key: key,
    prompt: '',
    options: {for (final label in quizLabels) label: ''},
  );
  factory QuizQuestion.fromJson(Json j) {
    final id = j.uuid('id');
    if (j.integer('position') < 1) j.fail();
    final options = j.list(
      'options',
      (o) => (label: o.str('label'), text: o.str('text')),
    );
    final q = QuizQuestion(
      key: id,
      id: id,
      position: j.integer('position'),
      prompt: j.str('prompt'),
      options: {for (final o in options) o.label: o.text},
      correct: j.str('correctOption'),
    );
    if (options.length != 4 || questionErrors(q).isNotEmpty) j.fail();
    return q;
  }
  Map<String, Object?> toJson() => {
    'id': ?id,
    'prompt': prompt.trim(),
    'options': [
      for (final label in quizLabels)
        {'label': label, 'text': options[label]!.trim()},
    ],
    'correctOption': correct,
  };
  QuizQuestion copyWith({
    String? prompt,
    Map<String, String>? options,
    String? correct,
  }) => QuizQuestion(
    key: key,
    id: id,
    position: position,
    prompt: prompt ?? this.prompt,
    options: options ?? this.options,
    correct: correct ?? this.correct,
  );
}

class StaffQuiz {
  StaffQuiz(Json j, {bool detail = false})
    : id = j.uuid('id'),
      sessionId = j.uuid('sessionId'),
      title = j.str('title'),
      description = j.str('description'),
      purpose = j.str('purpose'),
      score = j.str('maxScore'),
      status = j.str('status'),
      revision = j.integer('revision'),
      dueAt = j.strOrNull('dueAt'),
      timeLimit = j.has('timeLimitMinutes')
          ? j.integer('timeLimitMinutes')
          : null,
      publishedAt = j.dateTimeOrNull('publishedAt'),
      questions = j.has('questions')
          ? j.list('questions', QuizQuestion.fromJson)
          : null {
    if (j.str('type') != 'QUIZ' ||
        j.integer('maxAttempts') != 1 ||
        !['TEST', 'HOMEWORK'].contains(purpose) ||
        !['DRAFT', 'PUBLISHED', 'ARCHIVED'].contains(status) ||
        revision < 1 ||
        scoreHundredths(score) == null ||
        (detail && questions == null) ||
        (questions?.length ?? 0) > 200) {
      j.fail();
    }
    if (questions != null &&
        questions!.map((q) => q.id).toSet().length != questions!.length) {
      j.fail();
    }
    questions?.sort((a, b) => a.position.compareTo(b.position));
    if (dueAt != null) j.dateTime('dueAt');
    if (timeLimit != null && (timeLimit! < 1 || timeLimit! > 240)) j.fail();
  }
  final String id, sessionId, title, description, purpose, score, status;
  final int revision;
  final String? dueAt;
  final int? timeLimit;
  final DateTime? publishedAt;
  final List<QuizQuestion>? questions;
  Map<String, String> get metadata => {
    'title': title,
    'description': description,
    'purpose': purpose,
    'maxScore': score,
    'dueAt': dueAt ?? '',
    'timeLimit': timeLimit?.toString() ?? '',
  };
}

const initialQuizMetadata = {
  'title': '',
  'description': '',
  'purpose': '',
  'maxScore': '10',
  'dueAt': '',
  'timeLimit': '',
};
int? scoreHundredths(String value) {
  if (!RegExp(r'^(0|[1-9]\d{0,5})(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.'),
      score =
          int.parse(parts[0]) * 100 +
          int.parse((parts.length == 1 ? '' : parts[1]).padRight(2, '0'));
  return score > 0 ? score : null;
}

Map<String, String> metadataErrors(Map<String, String> m, bool create) {
  final errors = <String, String>{},
      title = m['title'] ?? '',
      description = m['description'] ?? '',
      due = m['dueAt'] ?? '',
      limit = m['timeLimit'] ?? '';
  if (title.trim().isEmpty || title.trim().length > 250) {
    errors['title'] = 'titleRequired';
  }
  if (description.length > 20000) errors['description'] = 'descriptionLong';
  if (create && (m['purpose'] ?? '').isEmpty) {
    errors['purpose'] = 'purposeRequired';
  }
  if (create &&
      scoreHundredths((m['maxScore'] ?? '').replaceAll(',', '.')) == null) {
    errors['maxScore'] = 'scoreInvalid';
  }
  if (due.isNotEmpty &&
      (!RegExp(
            r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,3})?)?(?:Z|[+-]\d{2}:\d{2})$',
          ).hasMatch(due) ||
          DateTime.tryParse(due) == null ||
          DateTime.tryParse(
                '${due.substring(0, 10)}T00:00:00Z',
              )?.toIso8601String().substring(0, 10) !=
              due.substring(0, 10))) {
    errors['dueAt'] = 'dueInvalid';
  }
  if (limit.isNotEmpty &&
      (!RegExp(r'^\d+$').hasMatch(limit) ||
          (int.tryParse(limit) ?? 0) < 1 ||
          (int.tryParse(limit) ?? 0) > 240)) {
    errors['timeLimit'] = 'timerInvalid';
  }
  return errors;
}

Map<String, String> questionErrors(QuizQuestion q) {
  final errors = <String, String>{};
  if (q.prompt.trim().isEmpty || q.prompt.trim().length > 5000) {
    errors['prompt'] = 'promptRequired';
  }
  for (final label in quizLabels) {
    if ((q.options[label] ?? '').trim().isEmpty ||
        (q.options[label] ?? '').trim().length > 2000) {
      errors[label] = 'optionRequired';
    }
  }
  if (!quizLabels.contains(q.correct)) {
    errors['correctOption'] = 'correctRequired';
  }
  return errors;
}

bool quizCanWrite(String classStatus, String? sessionStatus) =>
    !['DRAFT', 'COMPLETED', 'CANCELLED'].contains(classStatus) &&
    sessionStatus != 'CANCELLED';
bool quizEqual(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

class QuizIntent {
  const QuizIntent({
    required this.kind,
    this.id,
    this.sessionId,
    this.revision,
    this.metadata,
    this.questions,
    this.reason,
  });
  final String kind;
  final String? id, sessionId, reason;
  final int? revision;
  final Map<String, String>? metadata;
  final List<QuizQuestion>? questions;
}
