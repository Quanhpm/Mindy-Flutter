import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/session/session_controller.dart';
import 'operations_service.dart';

/// Clone `operations/hooks.ts` + `provider.tsx` (cache theo request, ghi xong thì các query đọc lại).

/// Tăng sau mỗi lần ghi thành công (`revision` của provider RN).
final opsRevisionProvider = NotifierProvider<OpsRevision, int>(OpsRevision.new);

class OpsRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(sessionEpochProvider);
    return 0;
  }

  void bump() => state++;
}

final opsCacheProvider = Provider<Map<OpsRequest, OpsData>>((ref) {
  ref.watch(sessionEpochProvider);
  return {};
});

@immutable
class OpsQueryState {
  const OpsQueryState({this.data, this.result, this.busy = false, this.footerError = false});
  final OpsData? data;
  final OpsResult? result;
  final bool busy;
  final bool footerError;

  bool get offline => result?.kind == OpsResultKind.offline;
  bool get hasMore => data != null && data!.count < data!.total;
  bool get fatal => result?.kind == OpsResultKind.denied || result?.kind == OpsResultKind.notFound;
}

final opsQueryProvider = NotifierProvider.autoDispose.family<OpsQuery, OpsQueryState, OpsRequest>(OpsQuery.new);

class OpsQuery extends Notifier<OpsQueryState> {
  OpsQuery(this.request);
  final OpsRequest request;
  int _seq = 0, _page = 1, _failed = 1;
  bool _inFlight = false;

  @override
  OpsQueryState build() {
    ref.watch(sessionEpochProvider);
    ref.watch(opsRevisionProvider);
    final life = AppLifecycleListener(onResume: () => unawaited(load()));
    ref.onDispose(() {
      _seq++;
      life.dispose();
    });
    Future.microtask(load);
    return OpsQueryState(data: ref.read(opsCacheProvider)[request], busy: true);
  }

  Future<OpsResult?> refresh() => load();
  Future<OpsResult?> retry() => load(_failed);
  Future<OpsResult?> more() => load(_page + 1);

  Future<OpsResult?> load([int next = 1]) async {
    if (!ref.mounted || _inFlight) return null;
    final seq = ++_seq;
    _inFlight = true;
    state = OpsQueryState(data: state.data, result: state.result, busy: true);
    final result = await ref.read(operationsServiceProvider).read(request.withPage(next));
    if (!ref.mounted || seq != _seq) return null;
    _inFlight = false;
    final cache = ref.read(opsCacheProvider);
    if (result.success) {
      var data = result.data!;
      final old = cache[request];
      if (next > 1 && old != null) data = old.mergeNext(data);
      cache[request] = data;
      _page = next;
      state = OpsQueryState(data: data, result: result);
    } else {
      if (result.kind == OpsResultKind.denied || result.kind == OpsResultKind.notFound) cache.remove(request);
      _failed = next;
      state = OpsQueryState(data: cache[request], result: result, footerError: next > 1);
    }
    return result;
  }
}

/// Clone `useOperationsMutation`: giữ intent (cùng Idempotency-Key) khi chưa chắc chắn.
class OpsMutator {
  OpsMutator(this._ref, this._onChange);
  final WidgetRef _ref;
  final VoidCallback _onChange;
  OpsResult? result;
  bool busy = false;
  OpsMutation? _pending;
  bool _locked = false;

  bool get uncertain => result?.kind == OpsResultKind.uncertain;

  void reset() {
    _pending = null;
    result = null;
    _onChange();
  }

  Future<OpsResult?> submit(OpsMutation intent, {bool retry = false}) async {
    if (_locked) return null;
    _locked = true;
    busy = true;
    _onChange();
    if (!retry || _pending == null) {
      _pending = intent.kind == OpsMutationKind.collect || intent.key.isNotEmpty ? intent : intent.withKey(const Uuid().v4());
    }
    final service = _ref.read(operationsServiceProvider);
    final revision = _ref.read(opsRevisionProvider.notifier);
    final value = await service.write(_pending!);
    result = value;
    busy = false;
    _locked = false;
    if (value.kind != OpsResultKind.uncertain) _pending = null;
    if (value.success) revision.bump();
    _onChange();
    return value;
  }
}
