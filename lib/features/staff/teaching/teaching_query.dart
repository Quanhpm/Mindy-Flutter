import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../shared/remote.dart';
import 'teaching_models.dart';
import 'teaching_service.dart';

/// Clone `hooks/useTeachingQuery.ts`: tải trang 1, "Tải thêm" gộp theo id, lỗi trang sau hiện ở footer,
/// lịch (`schedule`) tự đọc hết mọi trang, tự làm mới khi app quay lại foreground.
@immutable
class TeachingQueryState {
  const TeachingQueryState({
    this.data,
    this.error,
    this.loaded = false,
    this.busy = false,
    this.page = 1,
    this.footerError = false,
    this.footerOffline = false,
  });

  /// Dữ liệu đang hiển thị (giữ dữ liệu cũ khi làm mới lỗi, như `previous.current`).
  final TeachingData? data;

  /// Lỗi của lần tải trang 1 gần nhất (`result.kind != 'success'`).
  final RemoteError? error;

  /// Đã có kết quả (thành công hoặc lỗi) — `!!result`.
  final bool loaded;
  final bool busy;
  final int page;
  final bool footerError;
  final bool footerOffline;

  bool get offline => error?.kind == RemoteFailure.offline;

  /// `denied | notFound | unavailable`.
  bool get fatal =>
      error != null &&
      (error!.kind == RemoteFailure.denied ||
          error!.kind == RemoteFailure.notFound ||
          error!.kind == RemoteFailure.unavailable);

  bool get hasMore => data != null && _count(data!) < data!.total;

  static int _count(TeachingData d) => [d.classes.length, d.sessions.length, d.students.length, d.units.length]
      .reduce((a, b) => a > b ? a : b);

  TeachingQueryState copyWith({
    TeachingData? data,
    bool clearData = false,
    RemoteError? error,
    bool clearError = false,
    bool? loaded,
    bool? busy,
    int? page,
    bool? footerError,
    bool? footerOffline,
  }) => TeachingQueryState(
    data: clearData ? null : (data ?? this.data),
    error: clearError ? null : (error ?? this.error),
    loaded: loaded ?? this.loaded,
    busy: busy ?? this.busy,
    page: page ?? this.page,
    footerError: footerError ?? this.footerError,
    footerOffline: footerOffline ?? this.footerOffline,
  );
}

final teachingQueryProvider = NotifierProvider.autoDispose.family<TeachingQuery, TeachingQueryState, TeachingRequest>(
  TeachingQuery.new,
);

class TeachingQuery extends Notifier<TeachingQueryState> {
  TeachingQuery(this.request);
  final TeachingRequest request;

  int _sequence = 0;
  bool _inFlight = false;
  int _failedPage = 1;

  @override
  TeachingQueryState build() {
    ref.watch(sessionEpochProvider);
    final listener = AppLifecycleListener(onResume: () => unawaited(load(1, refresh: true)));
    ref.onDispose(() {
      _sequence++;
      listener.dispose();
    });
    Future.microtask(() => load(1));
    return const TeachingQueryState(busy: true);
  }

  TeachingService get _service => ref.read(teachingServiceProvider);

  Future<void> refresh() => load(1, refresh: true);

  Future<void> retry() => load(state.footerError ? _failedPage : 1, refresh: state.data != null);

  Future<void> more() => load(state.page + 1);

  Future<void> load(int next, {bool refresh = false}) async {
    if (!ref.mounted) return;
    if (next > 1 && _inFlight) return;
    final id = ++_sequence;
    _inFlight = true;
    var s = state.copyWith(busy: true, footerError: false, footerOffline: false);
    if (next == 1 && !refresh) {
      _failedPage = 1;
      s = s.copyWith(clearData: true, clearError: true, loaded: false);
    }
    state = s;
    bool stale() => !ref.mounted || id != _sequence;

    TeachingData? value;
    RemoteError? failure;
    try {
      var data = await _service.read(request.withPage(next));
      if (request.kind == TeachingKind.schedule) {
        var page = 2;
        while (data.sessions.length < data.total) {
          final extra = await _service.read(request.withPage(page++));
          if (stale()) return;
          final merged = mergeById(data.sessions, extra.sessions, (e) => e.id);
          if (merged.length == data.sessions.length) throw const RemoteError(RemoteFailure.error);
          data = data.copyWith(sessions: merged);
        }
      }
      value = data;
    } catch (e) {
      failure = RemoteError.from(e);
    }
    if (stale()) return;
    if (failure == null) {
      final old = next > 1 ? state.data : null;
      state = state.copyWith(
        data: old == null ? value : old.mergeNext(value!),
        clearError: true,
        loaded: true,
        page: next,
        busy: false,
      );
    } else if (failure.kind == RemoteFailure.denied ||
        failure.kind == RemoteFailure.notFound ||
        failure.kind == RemoteFailure.unavailable) {
      state = state.copyWith(clearData: true, error: failure, loaded: true, busy: false);
    } else if (next > 1) {
      _failedPage = next;
      state = state.copyWith(footerError: true, footerOffline: failure.offline, busy: false);
    } else {
      state = state.copyWith(error: failure, loaded: true, busy: false);
    }
    _inFlight = false;
  }
}
