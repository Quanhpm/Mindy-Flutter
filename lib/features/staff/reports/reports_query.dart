import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/session/session_controller.dart';
import '../shared/connectivity.dart';
import '../shared/remote.dart';
import 'reports_models.dart';
import 'reports_service.dart';

class ReportState {
  const ReportState({
    this.data,
    this.error,
    this.busy = true,
    this.footerError = false,
  });
  final ReportData? data;
  final RemoteError? error;
  final bool busy, footerError;
}

final reportQueryProvider = NotifierProvider.autoDispose
    .family<ReportQuery, ReportState, ReportRequest>(ReportQuery.new);

class ReportQuery extends Notifier<ReportState> {
  ReportQuery(this.request);
  final ReportRequest request;
  int _seq = 0;
  @override
  ReportState build() {
    ref.watch(sessionEpochProvider);
    ref.watch(staffOfflineProvider);
    final life = AppLifecycleListener(onResume: () => unawaited(refresh()));
    ref.onDispose(() {
      _seq++;
      life.dispose();
    });
    Future.microtask(refresh);
    return const ReportState();
  }

  Future<void> refresh() => load(1);
  Future<void> more() =>
      !ref.mounted ||
          state.busy ||
          state.data == null ||
          state.data!.count >= state.data!.total
      ? Future.value()
      : load(state.data!.page + 1);
  Future<void> load(int page) async {
    if (!ref.mounted) return;
    final seq = ++_seq, old = state.data;
    state = ReportState(data: old);
    try {
      if (ref.read(staffOfflineProvider)) {
        throw const RemoteError(RemoteFailure.offline);
      }
      final d = await ref
          .read(staffReportsServiceProvider)
          .read(request, page: page);
      if (!ref.mounted || seq != _seq) return;
      state = ReportState(
        busy: false,
        data: page == 1 || old == null
            ? d
            : ReportData(
                enrollments: mergeById(
                  old.enrollments,
                  d.enrollments,
                  (r) => r.id,
                ),
                history: mergeById(
                  old.history,
                  d.history,
                  (r) => '${r.enrollmentId}:${r.sessionId}',
                ),
                progress: mergeById(old.progress, d.progress, (r) => r.id),
                units: mergeById(
                  old.units,
                  d.units,
                  (r) => '${r.enrollmentId}:${r.unitId}',
                ),
                total: d.total,
                page: d.page,
                readonly: d.readonly,
                asOf: d.asOf,
                timeZone: d.timeZone,
              ),
      );
    } catch (e) {
      if (!ref.mounted || seq != _seq) return;
      final error = RemoteError.from(e);
      state = ReportState(
        data:
            [RemoteFailure.denied, RemoteFailure.notFound].contains(error.kind)
            ? null
            : old,
        error: error,
        busy: false,
        footerError: page > 1,
      );
    }
  }
}

final reportUnitNamesProvider = FutureProvider.autoDispose
    .family<Map<String, String>, String>((ref, id) {
      ref.watch(sessionEpochProvider);
      return ref.watch(staffReportsServiceProvider).unitNames(id);
    });
