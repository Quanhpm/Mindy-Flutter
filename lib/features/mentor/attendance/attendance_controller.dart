import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/format.dart';
import '../schedule/schedule_providers.dart';
import '../session/session_context_api.dart';
import 'attendance_api.dart';
import 'attendance_models.dart';

class AttendanceEditorState {
  AttendanceEditorState({
    required this.roster,
    required this.receivedAt,
    Map<String, AttendanceStatus> draft = const {},
    this.busy = false,
    this.error,
    this.retryPending = false,
    this.reloadRequired = false,
    this.conflict = false,
    this.sentBatches = 0,
    this.totalBatches = 0,
    this.changedCount = 0,
  }) : draft = Map.unmodifiable(draft);
  final AttendanceRoster roster;
  final DateTime receivedAt;
  final Map<String, AttendanceStatus> draft;
  final bool busy, retryPending, reloadRequired, conflict;
  final Object? error;
  final int sentBatches, totalBatches, changedCount;
  bool get dirty => draft.isNotEmpty;
  bool get locked => busy || retryPending || reloadRequired;
  AttendanceStatus statusOf(AttendanceRecord record) => draft[record.key] ?? record.status;

  // Dùng asOf server + thời gian đã trôi, không dùng sai số đồng hồ thiết bị để cấp quyền.
  DateTime serverNow(DateTime clientNow) => roster.header.session.asOf.add(clientNow.difference(receivedAt));
  bool editableAt(DateTime clientNow) {
    final deadline = roster.header.session.editableUntil;
    return roster.header.permissions.canEdit && deadline != null && serverNow(clientNow).isBefore(deadline);
  }

  bool startableAt(DateTime clientNow) =>
      roster.header.permissions.canStart &&
      Dates.localDay(serverNow(clientNow), roster.header.session.timeZone) ==
          Dates.localDay(roster.header.session.startsAt, roster.header.session.timeZone);

  AttendanceEditorState copy({
    AttendanceRoster? roster,
    DateTime? receivedAt,
    Map<String, AttendanceStatus>? draft,
    bool? busy,
    Object? error,
    bool clearError = false,
    bool? retryPending,
    bool? reloadRequired,
    bool? conflict,
    int? sentBatches,
    int? totalBatches,
    int? changedCount,
  }) => AttendanceEditorState(
    roster: roster ?? this.roster,
    receivedAt: receivedAt ?? this.receivedAt,
    draft: draft ?? this.draft,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
    retryPending: retryPending ?? this.retryPending,
    reloadRequired: reloadRequired ?? this.reloadRequired,
    conflict: conflict ?? this.conflict,
    sentBatches: sentBatches ?? this.sentBatches,
    totalBatches: totalBatches ?? this.totalBatches,
    changedCount: changedCount ?? this.changedCount,
  );
}

/// Giữ queue và call hiện tại trong RAM. Retry không được tạo key/body mới.
class _AttendanceFlow {
  _AttendanceFlow(this.operation, this.version, {this.batches = const [], this.fields = const {}});
  final AttendanceOperation operation;
  final List<List<AttendanceChange>> batches;
  final Map<String, Object?> fields;
  int version, index = 0, changedCount = 0;
  bool reloadOnly = false;
  IdempotentCall? current;
  int get length => operation == AttendanceOperation.mark ? batches.length : 1;
  Map<String, Object?> get body => operation == AttendanceOperation.mark
      ? attendanceBatchBody(batches[index], version)
      : {'expectedVersion': version, ...fields};
}

final attendanceEditorProvider = AsyncNotifierProvider.autoDispose
    .family<AttendanceController, AttendanceEditorState, String>(AttendanceController.new);

class AttendanceController extends AsyncNotifier<AttendanceEditorState> {
  AttendanceController(this.sessionId);
  final String sessionId;
  _AttendanceFlow? _flow;
  void Function()? _release;
  DateTime _now() => ref.read(mentorClockProvider)();
  AttendanceEditorState? get _editor => state.isLoading || state.hasError ? null : state.value;
  bool _valid(int epoch) => ref.mounted && ref.read(sessionEpochProvider) == epoch;

  @override
  Future<AttendanceEditorState> build() async {
    ref.watch(sessionEpochProvider);
    _flow = null;
    _release?.call();
    _release = null;
    final cancel = CancelToken();
    ref.onDispose(cancel.cancel);
    final api = ref.watch(mentorAttendanceApiProvider);
    final roster = await api.roster(sessionId, cancel: cancel);
    if (!ref.mounted) throw ApiError(status: 0, code: 'REQUEST_CANCELLED');
    return AttendanceEditorState(roster: roster, receivedAt: _now());
  }

  void setStatus(AttendanceRecord record, AttendanceStatus status) {
    final current = _editor;
    if (current == null || current.locked || !current.editableAt(_now())) return;
    if (!current.roster.records.any((row) => row.key == record.key)) return;
    // UI chỉ đánh Có mặt/Vắng; UNMARKED là trạng thái roster trước khi được đánh dấu.
    if (status == AttendanceStatus.UNMARKED) return;
    final draft = {...current.draft};
    if (status == record.status) {
      draft.remove(record.key);
    } else {
      draft[record.key] = status;
    }
    state = AsyncData(current.copy(draft: draft, clearError: !current.conflict));
  }

  void discardDraft() {
    final current = _editor;
    if (current == null || current.busy || _flow != null) return;
    state = AsyncData(current.copy(draft: const {}, conflict: false, clearError: !current.reloadRequired));
  }

  void reviewDraft() {
    final current = _editor;
    if (current == null || current.locked) return;
    state = AsyncData(current.copy(conflict: false, clearError: true));
  }

  Future<bool> start() => _single(AttendanceOperation.start);
  Future<bool> bulkPresent() => _single(AttendanceOperation.bulk, fields: {'checked': true});
  Future<bool> sync() => _single(AttendanceOperation.sync);
  Future<bool> finalize() => _single(AttendanceOperation.finalize);

  Future<bool> _single(AttendanceOperation operation, {Map<String, Object?> fields = const {}}) async {
    final current = _editor;
    if (current == null || current.locked || current.dirty || current.conflict || _flow != null) return false;
    final permissions = current.roster.header.permissions;
    final allowed = switch (operation) {
      AttendanceOperation.start => current.startableAt(_now()),
      AttendanceOperation.bulk => current.editableAt(_now()),
      AttendanceOperation.sync => permissions.canSync && current.editableAt(_now()),
      AttendanceOperation.finalize => permissions.canFinalize && current.editableAt(_now()),
      AttendanceOperation.mark => false,
    };
    if (!allowed) return false;
    return _begin(_AttendanceFlow(operation, current.roster.header.session.version, fields: fields));
  }

  Future<bool> save() async {
    final current = _editor;
    if (current == null || current.locked || current.conflict || _flow != null || !current.editableAt(_now())) {
      return false;
    }
    final changes = attendanceDiff(current.roster, current.draft);
    if (changes.isEmpty) return false;
    return _begin(
      _AttendanceFlow(
        AttendanceOperation.mark,
        current.roster.header.session.version,
        batches: attendanceBatches(changes),
      ),
    );
  }

  Future<bool> _begin(_AttendanceFlow flow) {
    _flow = flow;
    // Đóng sheet khi đang chờ retry vẫn giữ được call; đổi phiên sẽ reset build và bỏ RAM này.
    _release ??= ref.keepAlive().close;
    return _execute(flow);
  }

  Future<bool> retry() async {
    final current = _editor;
    if (current == null || current.busy) return false;
    final flow = _flow;
    if (flow != null) return _execute(flow);
    return reload();
  }

  Future<bool> _execute(_AttendanceFlow flow) async {
    final epoch = ref.read(sessionEpochProvider);
    final api = ref.read(mentorAttendanceApiProvider);
    final initial = _editor;
    if (initial == null || initial.busy) return false;
    state = AsyncData(
      initial.copy(
        busy: true,
        clearError: true,
        retryPending: false,
        sentBatches: flow.index,
        totalBatches: flow.length,
      ),
    );
    try {
      while (flow.index < flow.length) {
        final call = flow.current ??= IdempotentCall(flow.body);
        final result = await api.execute(sessionId, flow.operation, call);
        if (!_valid(epoch)) return false;
        if (result.header.session.version < flow.version) throw ApiError.invalidResponse(MentorAttendanceApi.errorCode);
        flow.version = result.header.session.version;
        flow.changedCount += result.changedEnrollmentIds.length + result.changedPlacementIds.length;
        flow.index++;
        flow.current = null;
        state = AsyncData(state.value!.copy(sentBatches: flow.index));
      }
      flow.reloadOnly = true;
      final roster = await api.roster(sessionId);
      if (!_valid(epoch)) return false;
      _clearFlow();
      state = AsyncData(AttendanceEditorState(roster: roster, receivedAt: _now(), changedCount: flow.changedCount));
      ref.invalidate(mentorScheduleProvider);
      ref.invalidate(mentorRoomProvider(sessionId));
      return true;
    } catch (error) {
      if (!_valid(epoch)) return false;
      final uncertain =
          error is ApiError && (error.status == 0 || error.status >= 500 || error.status == 408 || error.status == 429);
      if (uncertain) {
        state = AsyncData(
          state.value!.copy(busy: false, error: error, retryPending: true, reloadRequired: flow.reloadOnly),
        );
      } else {
        _clearFlow();
        await _reloadAfterError(error, epoch);
      }
      return false;
    }
  }

  void _clearFlow() {
    _flow = null;
    _release?.call();
    _release = null;
  }

  Map<String, AttendanceStatus> _rebasedDraft(AttendanceRoster roster, Map<String, AttendanceStatus> draft) => {
    for (final row in roster.records)
      if (draft.containsKey(row.key) && draft[row.key] != row.status) row.key: draft[row.key]!,
  };

  Future<void> _reloadAfterError(Object original, int epoch) async {
    final current = state.value!;
    try {
      final roster = await ref.read(mentorAttendanceApiProvider).roster(sessionId);
      if (!_valid(epoch)) return;
      final draft = _rebasedDraft(roster, current.draft);
      state = AsyncData(
        AttendanceEditorState(
          roster: roster,
          receivedAt: _now(),
          draft: draft,
          error: original,
          conflict: draft.isNotEmpty,
        ),
      );
    } catch (_) {
      if (_valid(epoch)) {
        state = AsyncData(current.copy(busy: false, error: original, retryPending: false, reloadRequired: true));
      }
    }
  }

  Future<bool> reload() async {
    final current = _editor;
    if (current == null || current.busy || _flow != null) return false;
    final epoch = ref.read(sessionEpochProvider);
    state = AsyncData(current.copy(busy: true));
    try {
      final roster = await ref.read(mentorAttendanceApiProvider).roster(sessionId);
      if (!_valid(epoch)) return false;
      final draft = _rebasedDraft(roster, current.draft);
      state = AsyncData(
        AttendanceEditorState(
          roster: roster,
          receivedAt: _now(),
          draft: draft,
          conflict:
              draft.isNotEmpty &&
              (current.conflict || roster.header.session.version != current.roster.header.session.version),
        ),
      );
      return true;
    } catch (error) {
      if (_valid(epoch)) state = AsyncData(current.copy(busy: false, error: error, reloadRequired: true));
      return false;
    }
  }
}
