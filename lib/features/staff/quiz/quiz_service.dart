import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/json.dart';
import '../../../core/session/session_controller.dart';
import '../shared/remote.dart';
import 'quiz_models.dart';

class QuizFailure implements Exception {
  const QuizFailure(this.kind, {this.code = '', this.requestId});
  final String kind, code;
  final String? requestId;
  static QuizFailure from(Object e, {bool write = false}) {
    if (e is QuizFailure) return e;
    if (e is ApiError) {
      return QuizFailure(
        e.code == 'SESSION_CHANGED' ||
                e.status == 401 ||
                (e.status == 403 && e.code != 'ORIGIN_NOT_ALLOWED')
            ? 'denied'
            : e.status == 404
            ? 'notFound'
            : e.status == 409 && e.code == 'ASSIGNMENT_VERSION_CONFLICT'
            ? 'conflict'
            : write && (e.isNetwork || e.status >= 500 || e.status == 408)
            ? 'uncertain'
            : e.isNetwork
            ? 'offline'
            : 'error',
        code: e.code,
        requestId: e.requestId,
      );
    }
    return QuizFailure(write ? 'uncertain' : 'error');
  }
}

final staffQuizServiceProvider = Provider((ref) {
  final epoch = ref.watch(sessionEpochProvider);
  return StaffQuizService(
    ref.watch(apiClientProvider),
    () => ref.mounted && ref.read(sessionEpochProvider) == epoch,
  );
});

class StaffQuizService {
  StaffQuizService(this.api, this.active);
  final ApiClient api;
  final bool Function() active;
  Future<T> _request<T>(
    Future<Object?> Function() call,
    T Function(Json) parse, {
    bool write = false,
  }) async {
    if (!active()) throw const QuizFailure('denied');
    try {
      final body = await call();
      if (!active()) throw const QuizFailure('denied');
      return parse(Json(body, 'INVALID_QUIZ_RESPONSE'));
    } catch (e) {
      throw QuizFailure.from(e, write: write);
    }
  }

  Future<Paged<StaffQuiz>> list(
    String classId, {
    String? sessionId,
    String? filterSession,
    String status = '',
    int page = 1,
    int pageSize = 20,
  }) => _request(
    () => api.get(
      sessionId == null
          ? 'mentor/classes/${resourceId(classId)}/assignments'
          : 'mentor/class-sessions/${resourceId(sessionId)}/assignments',
      query: {
        'type': 'QUIZ',
        'page': page,
        'pageSize': pageSize,
        if (status.isNotEmpty) 'status': status,
        if (filterSession != null && filterSession.isNotEmpty)
          'sessionId': resourceId(filterSession),
      },
    ),
    (j) {
      final p = Paged.fromJson(j, StaffQuiz.new);
      if (p.page != page ||
          p.pageSize != pageSize ||
          (sessionId != null && p.items.any((q) => q.sessionId != sessionId))) {
        j.fail();
      }
      return p;
    },
  );
  Future<StaffQuiz> detail(String id) => _request(
    () => api.get('mentor/assignments/${resourceId(id)}'),
    (j) => StaffQuiz(j, detail: true),
  );
  Future<StaffQuiz?> command(QuizIntent i, {StaffQuiz? previous}) async {
    String path, method;
    Map<String, Object?> body;
    if (i.kind == 'create') {
      final m = i.metadata!;
      if (metadataErrors(m, true).isNotEmpty) {
        throw const QuizFailure('error', code: 'INVALID_ASSIGNMENT_CONFIG');
      }
      path = 'mentor/class-sessions/${resourceId(i.sessionId)}/assignments';
      method = 'POST';
      body = {
        'type': 'QUIZ',
        'purpose': m['purpose'],
        'title': m['title']!.trim(),
        'description': m['description'],
        'maxScore': m['maxScore']!.replaceAll(',', '.'),
        'dueAt': m['dueAt']!.isEmpty ? null : m['dueAt'],
        'timeLimitMinutes': int.tryParse(m['timeLimit']!),
      };
    } else {
      if ((i.revision ?? 0) < 1) {
        throw const QuizFailure('error', code: 'INVALID_REVISION');
      }
      path = 'mentor/assignments/${resourceId(i.id)}';
      body = {'expectedRevision': i.revision};
      if (i.kind == 'metadata') {
        final m = i.metadata!;
        if (metadataErrors(m, false).isNotEmpty) {
          throw const QuizFailure('error', code: 'INVALID_ASSIGNMENT_CONFIG');
        }
        method = 'PATCH';
        final next = <String, Object?>{
          'title': m['title']!.trim(),
          'description': m['description'],
          'dueAt': m['dueAt']!.isEmpty ? null : m['dueAt'],
          'timeLimitMinutes': int.tryParse(m['timeLimit']!),
        };
        final old = previous == null
            ? null
            : {
                'title': previous.title,
                'description': previous.description,
                'dueAt': previous.dueAt,
                'timeLimitMinutes': previous.timeLimit,
              };
        body.addAll({
          for (final e in next.entries)
            if (old == null || old[e.key] != e.value) e.key: e.value,
        });
      } else if (i.kind == 'questions') {
        final qs = i.questions!;
        if (qs.isEmpty ||
            qs.length > 200 ||
            qs.any((q) => questionErrors(q).isNotEmpty)) {
          throw const QuizFailure('error', code: 'INVALID_QUIZ_QUESTIONS');
        }
        path += '/questions';
        method = 'PUT';
        body['questions'] = [for (final q in qs) q.toJson()];
      } else {
        method = i.kind == 'delete' ? 'DELETE' : 'POST';
        if (i.kind != 'delete') path += '/${i.kind}';
        if (i.kind == 'archive') {
          if ((i.reason ?? '').trim().isEmpty || i.reason!.trim().length > 2000) {
            throw const QuizFailure('error', code: 'REASON_REQUIRED');
          }
          body['reason'] = i.reason!.trim();
        }
      }
    }
    if (i.kind == 'delete') {
      if (!active()) throw const QuizFailure('denied');
      try {
        await api.delete(path, body: body);
        if (!active()) throw const QuizFailure('denied');
        return null;
      } catch (e) {
        throw QuizFailure.from(e, write: true);
      }
    }
    return _request(
      () => switch (method) {
        'PATCH' => api.patch(path, body: body),
        'PUT' => api.put(path, body: body),
        _ => api.post(path, body: body),
      },
      (j) {
        final q = StaffQuiz(j, detail: i.kind == 'questions');
        if (i.kind == 'create' ? q.sessionId != i.sessionId : q.id != i.id) {
          j.fail();
        }
        return q;
      },
      write: true,
    );
  }
}
