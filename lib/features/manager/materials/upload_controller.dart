import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/files_api.dart';
import '../../../core/network/file_models.dart';
import '../../../core/network/upload_client.dart';
import '../../../core/session/session_controller.dart';
import '../../mentor/materials/upload_policy.dart';

class ManagerUploadState {
  const ManagerUploadState({
    this.busy = false,
    this.progress = 0,
    this.file,
    this.error,
    this.fileId,
    this.checkRequired = false,
  });
  final bool busy, checkRequired;
  final double progress;
  final BinaryFileSummary? file;
  final Object? error;
  final String? fileId;
}

typedef ManagerUploadKey = ({String unitId, String slot});
final managerUploadWaitProvider = Provider<Future<void> Function(CancelToken)>(
  (ref) => (cancel) async {
    final done = Completer<void>();
    final wait = Timer(const Duration(seconds: 2), () => done.complete());
    cancel.whenCancel.then((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await done.future;
    } finally {
      wait.cancel();
    }
  },
);
final managerUploadProvider = NotifierProvider.autoDispose
    .family<ManagerReadyUpload, ManagerUploadState, ManagerUploadKey>(ManagerReadyUpload.new);

class ManagerReadyUpload extends Notifier<ManagerUploadState> {
  ManagerReadyUpload(this.key);
  final ManagerUploadKey key;
  CancelToken? _cancel;
  void Function()? _release;
  PickedUploadFile? _source;
  @override
  ManagerUploadState build() {
    ref.watch(sessionEpochProvider);
    _cancel?.cancel();
    _cancel = null;
    _release?.call();
    _release = null;
    _source = null;
    ref.onDispose(() => _cancel?.cancel());
    return const ManagerUploadState();
  }

  bool _valid(int epoch, CancelToken cancel) =>
      ref.mounted && ref.read(sessionEpochProvider) == epoch && !cancel.isCancelled;
  void cancel() {
    _cancel?.cancel();
    _release?.call();
    _release = null;
    state = ManagerUploadState(fileId: state.fileId, checkRequired: state.fileId != null);
  }

  Future<void> start(PickedUploadFile file) async {
    if (state.busy || state.checkRequired) return;
    _source = file;
    validateUploadFile(file.name, file.size, declaredMimeType: file.mimeType);
    final epoch = ref.read(sessionEpochProvider), cancel = _cancel = CancelToken();
    _release ??= ref.keepAlive().close;
    state = const ManagerUploadState(busy: true);
    try {
      final api = ref.read(filesApiProvider), put = ref.read(uploadClientProvider);
      final intent = await api.intent(
        courseUnitId: key.unitId,
        name: file.name,
        mimeType: file.mimeType,
        size: file.size,
        cancel: cancel,
      );
      if (!_valid(epoch, cancel)) return;
      state = ManagerUploadState(busy: true, fileId: intent.fileId);
      await put.put(
        intent,
        file.openRead(),
        file.size,
        cancel: cancel,
        onProgress: (sent, total) {
          if (_valid(epoch, cancel)) {
            state = ManagerUploadState(
              busy: true,
              progress: total > 0 ? (sent / total).clamp(0, 1) : 0,
              fileId: intent.fileId,
            );
          }
        },
      );
      if (!_valid(epoch, cancel)) return;
      // Lưu ID trước complete: mất response chỉ đọc trạng thái, không PUT lại.
      await api.complete(intent.fileId, cancel: cancel);
      if (!_valid(epoch, cancel)) return;
      await _poll(intent.fileId, epoch, cancel);
    } catch (error) {
      if (_valid(epoch, cancel)) {
        state = ManagerUploadState(error: error, fileId: state.fileId, checkRequired: state.fileId != null);
        if (state.fileId == null) {
          _release?.call();
          _release = null;
        }
      }
    }
  }

  Future<void> retryTransfer() async {
    if (state.busy || _source == null) return;
    // Người dùng yêu cầu upload mới; kiểm trạng thái object cũ trước, không tự PUT lại.
    final source = _source!, id = state.fileId, epoch = ref.read(sessionEpochProvider);
    if (id != null) {
      try {
        final status = await ref.read(filesApiProvider).status(id);
        if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return;
        if (status.status == FileStatus.READY || status.status == FileStatus.PROCESSING) {
          await check();
          return;
        }
      } catch (e) {
        if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return;
        state = ManagerUploadState(error: e, fileId: id, checkRequired: true);
        return;
      }
    }
    state = const ManagerUploadState();
    await start(source);
  }

  Future<void> check() async {
    if (state.busy || state.fileId == null) return;
    final id = state.fileId!, epoch = ref.read(sessionEpochProvider), cancel = _cancel = CancelToken();
    _release ??= ref.keepAlive().close;
    state = ManagerUploadState(busy: true, fileId: id);
    try {
      await _poll(id, epoch, cancel);
    } catch (error) {
      if (_valid(epoch, cancel)) state = ManagerUploadState(error: error, fileId: id, checkRequired: true);
    }
  }

  Future<void> _poll(String id, int epoch, CancelToken cancel) async {
    for (var n = 0; n < 60; n++) {
      if (!_valid(epoch, cancel)) return;
      final status = await ref.read(filesApiProvider).status(id, cancel: cancel);
      if (!_valid(epoch, cancel)) return;
      if (status.courseUnitId != key.unitId) throw ApiError.invalidResponse();
      if (status.status == FileStatus.READY) {
        state = ManagerUploadState(
          file: BinaryFileSummary(
            id: status.id,
            name: status.name,
            mimeType: status.mimeType!,
            size: status.size!,
            kind: status.kind!,
          ),
          fileId: id,
          progress: 1,
        );
        _release?.call();
        _release = null;
        return;
      }
      if (status.status == FileStatus.FAILED || status.status == FileStatus.DELETED) {
        state = ManagerUploadState(
          error: ApiError(status: 422, code: 'UPLOAD_PROCESSING_FAILED'),
          fileId: id,
        );
        _release?.call();
        _release = null;
        return;
      }
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
        state = ManagerUploadState(fileId: id, checkRequired: true);
        return;
      }
      await ref.read(managerUploadWaitProvider)(cancel);
    }
    if (_valid(epoch, cancel)) state = ManagerUploadState(fileId: id, checkRequired: true);
  }
}
