import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/session/session_controller.dart';
import '../shared/connectivity.dart';
import '../shared/remote.dart';
import 'materials_models.dart';
import 'materials_service.dart';

typedef MaterialListRequest = ({
  bool manager,
  String? classId,
  String? unitId,
  String status,
});
typedef MaterialDetailRequest = ({bool manager, String? classId, String id});
final materialRevisionProvider = NotifierProvider<MaterialRevision, int>(
  MaterialRevision.new,
);

class MaterialRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(sessionEpochProvider);
    return 0;
  }

  void bump() => state++;
}

final materialDetailProvider = FutureProvider.autoDispose
    .family<StaffMaterial, MaterialDetailRequest>((ref, r) {
      ref.watch(sessionEpochProvider);
      ref.watch(materialRevisionProvider);
      ref.watch(staffOfflineProvider);
      final life = AppLifecycleListener(onResume: ref.invalidateSelf);
      ref.onDispose(life.dispose);
      return ref
          .watch(staffMaterialServiceProvider)
          .detail(r.manager, r.classId, r.id);
    });
final materialNamesProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(staffMaterialServiceProvider).names(),
);

class MaterialListState {
  const MaterialListState({
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.busy = true,
    this.error,
    this.footerError = false,
  });
  final List<StaffMaterial> items;
  final int total, page;
  final bool busy, footerError;
  final MaterialFailure? error;
}

final materialListProvider = NotifierProvider.autoDispose
    .family<MaterialListQuery, MaterialListState, MaterialListRequest>(
      MaterialListQuery.new,
    );

class MaterialListQuery extends Notifier<MaterialListState> {
  MaterialListQuery(this.request);
  final MaterialListRequest request;
  int _seq = 0;
  @override
  MaterialListState build() {
    ref.watch(sessionEpochProvider);
    ref.watch(materialRevisionProvider);
    ref.watch(staffOfflineProvider);
    final life = AppLifecycleListener(onResume: () => unawaited(refresh()));
    ref.onDispose(() {
      _seq++;
      life.dispose();
    });
    Future.microtask(refresh);
    return const MaterialListState();
  }

  Future<void> refresh() => load(1);
  Future<void> more() =>
      !ref.mounted || state.busy || state.items.length >= state.total
      ? Future.value()
      : load(state.page + 1);
  Future<void> load(int page) async {
    if (!ref.mounted) return;
    final seq = ++_seq, old = state;
    state = MaterialListState(
      items: old.items,
      total: old.total,
      page: old.page,
    );
    try {
      if (ref.read(staffOfflineProvider)) {
        throw const MaterialFailure('offline');
      }
      final r = request,
          p = await ref
              .read(staffMaterialServiceProvider)
              .list(
                manager: r.manager,
                classId: r.classId,
                unitId: r.unitId,
                status: r.status,
                page: page,
              );
      if (!ref.mounted || seq != _seq) return;
      state = MaterialListState(
        items: page > 1 ? mergeById(old.items, p.items, (m) => m.id) : p.items,
        total: p.total,
        page: p.page,
        busy: false,
      );
    } catch (e) {
      if (!ref.mounted || seq != _seq) return;
      final err = MaterialFailure.from(e),
          fatal = ['denied', 'notFound', 'conflict'].contains(err.kind);
      state = MaterialListState(
        items: fatal ? const [] : old.items,
        total: fatal ? 0 : old.total,
        page: old.page,
        busy: false,
        error: err,
        footerError: page > 1,
      );
    }
  }
}
