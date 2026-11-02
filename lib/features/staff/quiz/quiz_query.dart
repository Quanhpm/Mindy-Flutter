import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/session/session_controller.dart';
import '../shared/connectivity.dart';
import '../shared/remote.dart';
import 'quiz_models.dart';
import 'quiz_service.dart';

typedef QuizListRequest = ({
  String classId,
  String? sessionId,
  String? filterSession,
  String status,
});
final quizRevisionProvider = NotifierProvider<QuizRevision, int>(
  QuizRevision.new,
);

class QuizRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(sessionEpochProvider);
    return 0;
  }

  void bump() => state++;
}

final quizDetailProvider = FutureProvider.autoDispose.family<StaffQuiz, String>(
  (ref, id) {
    ref.watch(sessionEpochProvider);
    ref.watch(quizRevisionProvider);
    ref.watch(staffOfflineProvider);
    final life = AppLifecycleListener(onResume: ref.invalidateSelf);
    ref.onDispose(life.dispose);
    return ref.watch(staffQuizServiceProvider).detail(id);
  },
);

class QuizListState {
  const QuizListState({
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.busy = true,
    this.error,
    this.footerError = false,
  });
  final List<StaffQuiz> items;
  final int total, page;
  final bool busy, footerError;
  final QuizFailure? error;
}

final quizListProvider = NotifierProvider.autoDispose
    .family<QuizListQuery, QuizListState, QuizListRequest>(QuizListQuery.new);

class QuizListQuery extends Notifier<QuizListState> {
  QuizListQuery(this.request);
  final QuizListRequest request;
  int _seq = 0;
  @override
  QuizListState build() {
    ref.watch(sessionEpochProvider);
    ref.watch(quizRevisionProvider);
    ref.watch(staffOfflineProvider);
    final life = AppLifecycleListener(onResume: () => unawaited(refresh()));
    ref.onDispose(() {
      _seq++;
      life.dispose();
    });
    Future.microtask(refresh);
    return const QuizListState();
  }

  Future<void> refresh() => load(1);
  Future<void> more() =>
      !ref.mounted || state.busy || state.items.length >= state.total
      ? Future.value()
      : load(state.page + 1);
  Future<void> load(int page) async {
    if (!ref.mounted) return;
    final seq = ++_seq, old = state;
    state = QuizListState(items: old.items, total: old.total, page: old.page);
    try {
      if (ref.read(staffOfflineProvider)) throw const QuizFailure('offline');
      final r = request,
          p = await ref
              .read(staffQuizServiceProvider)
              .list(
                r.classId,
                sessionId: r.sessionId,
                filterSession: r.filterSession,
                status: r.status,
                page: page,
              );
      if (!ref.mounted || seq != _seq) return;
      if (p.items.isEmpty && old.items.length < p.total && page > 1) {
        throw const QuizFailure('error', code: 'INVALID_PAGE');
      }
      state = QuizListState(
        items: page > 1 ? mergeById(old.items, p.items, (q) => q.id) : p.items,
        total: p.total,
        page: p.page,
        busy: false,
      );
    } catch (e) {
      if (!ref.mounted || seq != _seq) return;
      final error = QuizFailure.from(e),
          fatal = ['denied', 'notFound'].contains(error.kind);
      state = QuizListState(
        items: fatal ? const [] : old.items,
        total: fatal ? 0 : old.total,
        page: old.page,
        busy: false,
        error: error,
        footerError: page > 1,
      );
    }
  }
}
