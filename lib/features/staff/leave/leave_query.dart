import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/session/session_controller.dart';
import '../shared/connectivity.dart';
import 'leave_service.dart';

/// Clone `leave/hooks.ts` + `LeaveProvider.tsx`: cache theo request, ghi xong thì xóa cache và đọc lại.

final leaveRevisionProvider = NotifierProvider<LeaveRevision, int>(
  LeaveRevision.new,
);

class LeaveRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(sessionEpochProvider);
    return 0;
  }

  bool get active => ref.mounted;

  /// `publish()`: xóa cache + báo mọi query đọc lại.
  void publish() {
    ref.read(leaveCacheProvider).clear();
    state++;
  }
}

final leaveCacheProvider = Provider<Map<LeaveReadRequest, LeaveData>>((ref) {
  ref.watch(sessionEpochProvider);
  return {};
});

/// Khóa theo tài nguyên (`memory.locks`): một intent đang chờ thì intent khác cùng đơn bị chặn.
final leaveLocksProvider = Provider<Map<String, String>>((ref) {
  ref.watch(sessionEpochProvider);
  return {};
});

@immutable
class LeaveQueryState {
  const LeaveQueryState({
    this.data,
    this.result,
    this.busy = false,
    this.footerError = false,
  });
  final LeaveData? data;
  final LeaveOutcome? result;
  final bool busy;
  final bool footerError;

  bool get offline => result?.kind == LeaveOutcomeKind.offline;
  int get count => data?.count ?? 0;
  bool get hasMore => data != null && count < data!.total;
  bool get fatal =>
      result?.kind == LeaveOutcomeKind.denied ||
      result?.kind == LeaveOutcomeKind.notFound;
}

final leaveQueryProvider = NotifierProvider.autoDispose
    .family<LeaveQuery, LeaveQueryState, LeaveReadRequest>(LeaveQuery.new);

class LeaveQuery extends Notifier<LeaveQueryState> {
  LeaveQuery(this.request);
  final LeaveReadRequest request;
  int _seq = 0, _page = 1;
  bool _inFlight = false;

  @override
  LeaveQueryState build() {
    ref.watch(sessionEpochProvider);
    ref.watch(leaveRevisionProvider);
    ref.watch(staffOfflineProvider);
    _inFlight = false;
    final life = AppLifecycleListener(onResume: () => unawaited(load()));
    ref.onDispose(() {
      _seq++;
      life.dispose();
    });
    Future.microtask(load);
    return LeaveQueryState(
      data: ref.read(leaveCacheProvider)[request],
      busy: true,
    );
  }

  Future<LeaveData?> refresh() => load();
  Future<LeaveData?> retry() => load(state.footerError ? _page + 1 : 1);
  Future<LeaveData?> more() {
    if (!ref.mounted || _inFlight || state.offline || !state.hasMore) {
      return Future.value();
    }
    return load(_page + 1);
  }

  Future<LeaveData?> load([int next = 1]) async {
    if (!ref.mounted || (_inFlight && next > 1)) return null;
    final seq = ++_seq;
    _inFlight = true;
    final cache = ref.read(leaveCacheProvider);
    final cached = state.data ?? cache[request];
    state = LeaveQueryState(data: cached, busy: true);
    final result = ref.read(staffOfflineProvider)
        ? const LeaveOutcome(LeaveOutcomeKind.offline)
        : await ref.read(leaveServiceProvider).read(request.withPage(next));
    if (!ref.mounted || seq != _seq) return null;
    _inFlight = false;
    if (result.success) {
      var data = result.data!;
      if (next > 1 && cached != null) data = cached.mergeNext(data);
      _page = next;
      cache[request] = data;
      state = LeaveQueryState(data: data, result: result);
      return data;
    }
    final forbidden =
        result.kind == LeaveOutcomeKind.denied ||
        result.kind == LeaveOutcomeKind.notFound;
    if (forbidden) cache.remove(request);
    state = LeaveQueryState(
      data: forbidden ? null : cached,
      result: result,
      footerError: next > 1,
    );
    return null;
  }
}

/// Clone `useLeaveMutation`: giữ intent (cùng Idempotency-Key) khi chưa chắc chắn.
class LeaveMutator {
  LeaveMutator(this._ref, this._onChange);
  final WidgetRef _ref;
  final VoidCallback _onChange;
  LeaveOutcome? result;
  bool busy = false;
  LeaveIntent? intent;
  bool _locked = false;

  bool get uncertain => result?.kind == LeaveOutcomeKind.uncertain;

  void clear() {
    if (intent == null) {
      result = null;
      _onChange();
    }
  }

  Future<LeaveOutcome?> submit(
    LeaveIntent input, {
    bool offline = false,
  }) async {
    if (_locked || offline || _ref.read(staffOfflineProvider)) return null;
    final value = intent ?? input.withKey(const Uuid().v4());
    final resource = value.kind == LeaveIntentKind.create
        ? 'create'
        : (value.id ?? '');
    final locks = _ref.read(leaveLocksProvider);
    final active = locks[resource];
    if (active != null && active != value.key) return null;
    locks[resource] = value.key;
    intent = value;
    _locked = true;
    busy = true;
    _onChange();
    final service = _ref.read(leaveServiceProvider);
    final container = ProviderScope.containerOf(_ref.context, listen: false);
    final epoch = container.read(sessionEpochProvider);
    final revision = _ref.read(leaveRevisionProvider.notifier);
    LeaveOutcome response;
    try {
      response = await service.write(value);
    } catch (_) {
      response = const LeaveOutcome(LeaveOutcomeKind.uncertain);
    }
    _locked = false;
    if (!revision.active || container.read(sessionEpochProvider) != epoch) {
      locks.remove(resource);
      intent = null;
      busy = false;
      return null;
    }
    if (response.kind != LeaveOutcomeKind.uncertain) {
      intent = null;
      locks.remove(resource);
    }
    if (response.success || response.kind == LeaveOutcomeKind.denied) {
      revision.publish();
    }
    result = response;
    busy = false;
    _onChange();
    return response;
  }
}
