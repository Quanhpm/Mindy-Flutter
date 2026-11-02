import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../shared/remote.dart';
import '../teaching/teaching_models.dart';
import 'attendance_logic.dart';
import 'attendance_models.dart';
import 'attendance_service.dart';

/// Clone `attendance/hooks.ts` + phần cache/publish của `AttendanceProvider.tsx`.

/// Sự kiện sau khi ghi thành công: các query liên quan tự tải lại.
@immutable
class AttendanceEvent {
  const AttendanceEvent({required this.sessionId, required this.note, required this.kind, required this.role, required this.seq});
  final String sessionId;
  final bool note;
  final IntentKind kind;
  final TeachingRole role;
  final int seq;
}

final attendanceEventsProvider = NotifierProvider<AttendanceEvents, AttendanceEvent?>(AttendanceEvents.new);

class AttendanceEvents extends Notifier<AttendanceEvent?> {
  int _seq = 0;

  @override
  AttendanceEvent? build() {
    ref.watch(sessionEpochProvider);
    return null;
  }

  void publish({required String sessionId, required bool note, required IntentKind kind, required TeachingRole role}) {
    state = AttendanceEvent(sessionId: sessionId, note: note, kind: kind, role: role, seq: ++_seq);
  }
}

/// Cache dữ liệu theo request (RN `cache`): mở lại màn hiện dữ liệu cũ trong lúc tải lại.
final attendanceCacheProvider = Provider<Map<AttendanceRequest, AttendanceData>>((ref) {
  ref.watch(sessionEpochProvider);
  return {};
});

@immutable
class AttendanceQueryState {
  const AttendanceQueryState({this.data, this.error, this.loaded = false, this.busy = false, this.footerError = false});
  final AttendanceData? data;
  final RemoteError? error;
  final bool loaded;
  final bool busy;
  final bool footerError;

  bool get offline => error?.kind == RemoteFailure.offline;
  bool get fatal => error?.kind == RemoteFailure.denied || error?.kind == RemoteFailure.notFound;
}

final attendanceQueryProvider =
    NotifierProvider.autoDispose.family<AttendanceQuery, AttendanceQueryState, AttendanceRequest>(AttendanceQuery.new);

class AttendanceQuery extends Notifier<AttendanceQueryState> {
  AttendanceQuery(this.request);
  final AttendanceRequest request;

  int _sequence = 0, _page = 1, _opened = 1, _failed = 1;
  bool _pending = false;

  Map<AttendanceRequest, AttendanceData> get _cache => ref.read(attendanceCacheProvider);

  @override
  AttendanceQueryState build() {
    ref.watch(sessionEpochProvider);
    final cached = ref.read(attendanceCacheProvider)[request];
    final life = AppLifecycleListener(onResume: () => unawaited(load()));
    ref.onDispose(() {
      _sequence++;
      life.dispose();
    });
    ref.listen(attendanceEventsProvider, (_, event) {
      if (event != null && _matches(event)) unawaited(load());
    });
    Future.microtask(load);
    return AttendanceQueryState(data: cached, busy: true);
  }

  bool _matches(AttendanceEvent e) {
    final broad =
        const [IntentKind.finalize, IntentKind.recover, IntentKind.updateSession].contains(e.kind) ||
        (e.role == TeachingRole.MANAGER && const [IntentKind.save, IntentKind.bulk].contains(e.kind));
    if (e.note) return request.kind == AttendanceKind.note && request.sessionId == e.sessionId;
    return (request.sessionId == e.sessionId &&
            const [AttendanceKind.attendance, AttendanceKind.context, AttendanceKind.candidates].contains(request.kind)) ||
        (broad &&
            (request.kind == AttendanceKind.incomplete ||
                request.kind == AttendanceKind.managerSessions ||
                (request.sessionId == e.sessionId && request.kind == AttendanceKind.audits)));
  }

  Future<void> refresh() => load();

  Future<void> retry() => load(next: state.footerError ? _failed : 1);

  Future<void> more() => load(next: _page + 1);

  /// [preserve] = giữ dữ liệu cũ khi lỗi (mặc định, như RN).
  Future<void> load({int next = 1, bool preserve = true}) async {
    if (!ref.mounted || _pending) return;
    _pending = true;
    final id = ++_sequence;
    state = AttendanceQueryState(data: state.data, error: state.error, loaded: state.loaded, busy: true);
    bool stale() => !ref.mounted || id != _sequence;
    final service = ref.read(attendanceServiceProvider);
    AttendanceData? value;
    RemoteError? failure;
    var loadedPage = next;
    try {
      var data = await service.read(request.withPage(next));
      if (request.all || (preserve && next == 1 && _opened > 1)) {
        var p = next;
        while (request.all ? data.countFor(request.kind) < data.total : p < _opened) {
          final extra = await service.read(request.withPage(++p));
          if (stale()) return;
          final merged = data.mergeNext(extra);
          if (merged.countFor(request.kind) == data.countFor(request.kind)) {
            throw const RemoteError(RemoteFailure.error, requestId: 'pagination');
          }
          data = merged;
        }
        loadedPage = p;
      }
      value = data;
    } catch (e) {
      failure = RemoteError.from(e);
    }
    if (stale()) return;
    _pending = false;
    if (failure == null) {
      var data = value!;
      if (next > 1) {
        final previous = _cache[request];
        if (previous != null) data = previous.mergeNext(data);
      }
      _page = loadedPage;
      if (loadedPage > _opened) _opened = loadedPage;
      _cache[request] = data;
      state = AttendanceQueryState(data: data, loaded: true);
    } else if (failure.kind == RemoteFailure.denied || failure.kind == RemoteFailure.notFound) {
      _cache.remove(request);
      state = AttendanceQueryState(error: failure, loaded: true);
    } else if (next > 1) {
      _failed = next;
      state = AttendanceQueryState(data: state.data, error: state.error, loaded: state.loaded, footerError: true);
    } else if (!preserve) {
      _cache.remove(request);
      state = AttendanceQueryState(error: failure, loaded: true);
    } else {
      state = AttendanceQueryState(data: state.data, error: failure, loaded: true);
    }
  }
}

/// Clone `useAttendanceMutation`: khoá bấm lặp, giữ intent (cùng Idempotency-Key) khi kết quả chưa chắc chắn.
class AttendanceMutator {
  AttendanceMutator(this._ref, this._onChange);
  final WidgetRef _ref;
  final VoidCallback _onChange;

  bool busy = false;
  AttendanceIntent? intent;
  WriteResult? result;
  bool _lock = false;

  bool get uncertain => result?.kind == WriteKind.uncertain || (result?.kind == WriteKind.error && result?.code == 'SERVER');

  void clear() {
    result = null;
    intent = null;
    _onChange();
  }

  /// [value] không cần key; [retry] = gửi lại intent cũ cùng key.
  Future<WriteResult?> submit(AttendanceIntent value, {bool retry = false}) async {
    if (_lock) return null;
    _lock = true;
    busy = true;
    _onChange();
    final next = retry && intent != null ? intent! : value.withKey(newIntentKey());
    intent = next;
    final service = _ref.read(attendanceServiceProvider);
    final events = _ref.read(attendanceEventsProvider.notifier);
    final response = await service.write(next);
    result = response;
    busy = false;
    _lock = false;
    if (response.success) {
      intent = null;
      events.publish(sessionId: next.sessionId, note: next.kind == IntentKind.note, kind: next.kind, role: next.role);
    } else if (!uncertain) {
      intent = null;
    }
    _onChange();
    return response;
  }
}

/// `useServerNow`: giờ server suy ra từ `asOf` + thời gian đã trôi trên máy.
DateTime serverNow(DateTime? asOf, DateTime receivedAt) {
  if (asOf == null) return DateTime.now();
  final elapsed = DateTime.now().difference(receivedAt);
  return asOf.add(elapsed.isNegative ? Duration.zero : elapsed);
}
