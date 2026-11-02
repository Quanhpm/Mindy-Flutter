import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/file_models.dart';
import '../../../core/network/upload_client.dart';
import '../../../core/session/session_controller.dart';
import '../classes/classes_models.dart';
import '../classes/classes_providers.dart';
import '../schedule/schedule_providers.dart' show mentorClockProvider;
import 'files_api.dart';
import 'materials_api.dart';
import 'materials_models.dart';
import 'materials_providers.dart';
import 'upload_policy.dart';

enum UploadStep { idle, permission, intent, transfer, complete, processing, draft, verify, done }

class UploadState {
  const UploadState({
    this.step = UploadStep.idle,
    this.busy = false,
    this.fileName,
    this.unitTitle,
    this.title,
    this.size,
    this.progress = 0,
    this.error,
    this.canRetry = false,
    this.requiresVerification = false,
    this.material,
  });
  final UploadStep step;
  final bool busy, canRetry, requiresVerification;
  final String? fileName, unitTitle, title;
  final int? size;
  final double progress;
  final Object? error;
  final MentorMaterial? material;
  bool get hasWork => step != UploadStep.idle && step != UploadStep.done;
  UploadState copy({
    UploadStep? step,
    bool? busy,
    double? progress,
    Object? error,
    bool clearError = false,
    bool? canRetry,
    bool? requiresVerification,
    MentorMaterial? material,
  }) => UploadState(
    step: step ?? this.step,
    busy: busy ?? this.busy,
    fileName: fileName,
    unitTitle: unitTitle,
    title: title,
    size: size,
    progress: progress ?? this.progress,
    error: clearError ? null : error ?? this.error,
    canRetry: canRetry ?? this.canRetry,
    requiresVerification: requiresVerification ?? this.requiresVerification,
    material: material ?? this.material,
  );
}

Future<void> _waitUpload(Duration duration, CancelToken cancel) {
  final completer = Completer<void>();
  final timer = Timer(duration, () => completer.complete());
  cancel.whenCancel.then((_) {
    timer.cancel();
    if (!completer.isCompleted) {
      completer.completeError(ApiError(status: 0, code: 'UPLOAD_CANCELLED'));
    }
  });
  return completer.future;
}

final uploadWaitProvider = Provider<Future<void> Function(Duration, CancelToken)>((ref) => _waitUpload);
final mentorUploadProvider = NotifierProvider.autoDispose.family<MentorUploadController, UploadState, String>(
  MentorUploadController.new,
);

class _UploadFlow {
  _UploadFlow({
    required this.file,
    required this.unit,
    required this.title,
    required this.description,
    required this.actorId,
  });
  final PickedUploadFile file;
  final MentorUnit unit;
  final String title, actorId;
  final String? description;
  FileUploadIntent? intent;
  FileUploadStatus? status;
  bool transferred = false, completeAttempted = false, draftMayExist = false;
}

/// Giữ flow trong RAM qua đóng/mở trang. POST tạo material không có receipt/idempotency:
/// nếu mất response, chỉ đối chiếu fileId qua danh sách, tuyệt đối không tự POST lại.
class MentorUploadController extends Notifier<UploadState> {
  MentorUploadController(this.classId);
  final String classId;
  _UploadFlow? _flow;
  CancelToken? _cancel;
  Future<bool>? _job;
  void Function()? _release;
  @override
  UploadState build() {
    ref.watch(sessionEpochProvider);
    _cancel?.cancel();
    _flow = null;
    _job = null;
    _release?.call();
    _release = null;
    ref.onDispose(() => _cancel?.cancel());
    return const UploadState();
  }

  bool _valid(int epoch) => ref.mounted && ref.read(sessionEpochProvider) == epoch;
  DateTime _now() => ref.read(mentorClockProvider)();
  void _hold() {
    _release ??= ref.keepAlive().close;
  }

  void _step(UploadStep step) => state = state.copy(step: step, clearError: true, canRetry: false);
  void _assertRunning(int epoch, CancelToken cancel) {
    if (!_valid(epoch) || cancel.isCancelled) {
      throw ApiError(status: 0, code: 'UPLOAD_CANCELLED');
    }
  }

  Future<bool> start({
    required PickedUploadFile file,
    required MentorUnit unit,
    required String title,
    String? description,
  }) {
    if (state.busy || _flow != null) {
      return Future.value(false);
    }
    final actor = ref.read(sessionProvider).user;
    if (actor == null) {
      return Future.value(false);
    }
    _flow = _UploadFlow(
      file: file,
      unit: unit,
      title: title.trim(),
      description: description?.trim(),
      actorId: actor.id,
    );
    state = UploadState(
      step: UploadStep.permission,
      busy: true,
      fileName: file.name,
      unitTitle: unit.title,
      title: title.trim(),
      size: file.size,
    );
    _hold();
    return _begin(manualRetry: false);
  }

  Future<bool> retry() {
    if (state.busy || !state.canRetry || _flow == null) {
      return Future.value(false);
    }
    state = state.copy(busy: true, clearError: true, canRetry: false);
    return _begin(manualRetry: true);
  }

  Future<bool> _begin({required bool manualRetry}) {
    final epoch = ref.read(sessionEpochProvider), cancel = CancelToken();
    _cancel = cancel;
    final flow = _flow!;
    // Chụp service trước await; callback cũ không đọc provider của phiên mới.
    final files = ref.read(mentorFilesApiProvider),
        materials = ref.read(mentorMaterialsApiProvider),
        upload = ref.read(uploadClientProvider),
        wait = ref.read(uploadWaitProvider);
    return _job = _run(flow, epoch, cancel, files, materials, upload, wait, manualRetry: manualRetry);
  }

  Future<void> cancel() async {
    _cancel?.cancel();
    await _job;
  }

  /// UI xác nhận trước khi bỏ flow đang dở. Không có API xóa intent/file mồ côi.
  bool reset({bool abandonUnconfirmed = false}) {
    if (state.busy || (state.requiresVerification && !abandonUnconfirmed)) {
      return false;
    }
    _flow = null;
    _release?.call();
    _release = null;
    state = const UploadState();
    return true;
  }

  bool _ambiguous(Object error) =>
      error is! ApiError || error.status == 0 || error.status == 408 || error.status >= 500;
  void _checkFile(_UploadFlow flow, FileUploadStatus file) {
    if (file.id != flow.intent!.fileId ||
        file.courseUnitId != flow.unit.courseUnitId ||
        file.declaredSize != flow.file.size ||
        file.name != flow.file.name ||
        (file.status == FileStatus.READY && file.mimeType != flow.file.mimeType)) {
      throw ApiError.invalidResponse(MentorFilesApi.errorCode);
    }
  }

  void _finish(_UploadFlow flow, MentorMaterialDetail detail) {
    final material = detail.material;
    if (material.file?.id != flow.intent!.fileId ||
        material.courseUnitId != flow.unit.courseUnitId ||
        material.classId != classId ||
        material.createdBy != flow.actorId) {
      throw ApiError.invalidResponse(MentorMaterialsApi.errorCode);
    }
    state = state.copy(
      step: UploadStep.done,
      busy: false,
      clearError: true,
      canRetry: false,
      requiresVerification: false,
      progress: 1,
      material: material,
    );
    ref.invalidate(mentorMaterialsProvider(classId));
    _flow = null;
    _release?.call();
    _release = null;
  }

  Future<bool> _run(
    _UploadFlow flow,
    int epoch,
    CancelToken cancel,
    MentorFilesApi files,
    MentorMaterialsApi materials,
    UploadClient upload,
    Future<void> Function(Duration, CancelToken) wait, {
    required bool manualRetry,
  }) async {
    try {
      validateUploadFile(flow.file.name, flow.file.size, declaredMimeType: flow.file.mimeType);
      if (flow.title.isEmpty || flow.title.length > 250 || (flow.description?.length ?? 0) > 5000) {
        throw ApiError(status: 422, code: 'UPLOAD_METADATA_INVALID');
      }
      _step(UploadStep.permission);
      ref.invalidate(mentorPrimaryWorkspaceProvider(classId));
      final workspace = await ref.read(mentorPrimaryWorkspaceProvider(classId).future);
      _assertRunning(epoch, cancel);
      if (workspace.readonly || !workspace.authorMaterials) {
        throw ApiError(status: 403, code: 'MATERIAL_ACCESS_DENIED');
      }
      final units = await ref.read(mentorClassUnitsProvider(classId).future);
      _assertRunning(epoch, cancel);
      if (!units.any(
        (unit) => unit.id == flow.unit.id && unit.classId == classId && unit.courseUnitId == flow.unit.courseUnitId,
      )) {
        throw ApiError(status: 422, code: 'MATERIAL_SCOPE_MISMATCH');
      }
      if (flow.draftMayExist) {
        _step(UploadStep.verify);
        final found = (await materials.all(classId, flow.unit, cancel: cancel))
            .where(
              (m) =>
                  m.file?.id == flow.intent!.fileId &&
                  m.createdBy == flow.actorId &&
                  m.classId == classId &&
                  m.courseUnitId == flow.unit.courseUnitId,
            )
            .toList();
        _assertRunning(epoch, cancel);
        if (found.length != 1) {
          throw ApiError(status: 409, code: 'UPLOAD_DRAFT_UNCONFIRMED');
        }
        final detail = await materials.detail(classId, found.single.id, cancel: cancel);
        _assertRunning(epoch, cancel);
        _finish(flow, detail);
        return true;
      }
      if (flow.intent != null && !flow.transferred && !_now().isBefore(flow.intent!.uploadExpiresAt)) {
        if (!manualRetry) {
          throw ApiError(status: 409, code: 'UPLOAD_URL_EXPIRED');
        }
        flow.intent = null;
        flow.status = null;
        flow.completeAttempted = false;
      }
      if (flow.intent == null) {
        _step(UploadStep.intent);
        flow.intent = await files.intent(
          classId: classId,
          unitId: flow.unit.id,
          courseUnitId: flow.unit.courseUnitId,
          name: flow.file.name,
          mimeType: flow.file.mimeType,
          size: flow.file.size,
          cancel: cancel,
        );
        _assertRunning(epoch, cancel);
      }
      if (!flow.transferred) {
        if (!_now().isBefore(flow.intent!.uploadExpiresAt)) {
          throw ApiError(status: 409, code: 'UPLOAD_URL_EXPIRED');
        }
        _step(UploadStep.transfer);
        await upload.put(
          flow.intent!,
          flow.file.openRead(),
          flow.file.size,
          cancel: cancel,
          onProgress: (sent, total) {
            if (_valid(epoch) && !cancel.isCancelled) {
              state = state.copy(progress: (sent / flow.file.size).clamp(0, 1));
            }
          },
        );
        _assertRunning(epoch, cancel);
        flow.transferred = true;
      }
      _step(UploadStep.complete);
      if (flow.completeAttempted) {
        flow.status = await files.status(flow.intent!.fileId, cancel: cancel);
        _assertRunning(epoch, cancel);
        _checkFile(flow, flow.status!);
      }
      if (flow.status == null || flow.status!.status == FileStatus.PENDING_UPLOAD) {
        flow.completeAttempted = true;
        try {
          flow.status = await files.complete(flow.intent!.fileId, cancel: cancel);
        } catch (error) {
          if (!_ambiguous(error)) {
            rethrow;
          }
          _assertRunning(epoch, cancel);
          // Mất response complete: đọc trước; PENDING vẫn để người dùng bấm retry.
          flow.status = await files.status(flow.intent!.fileId, cancel: cancel);
          _assertRunning(epoch, cancel);
          _checkFile(flow, flow.status!);
          if (flow.status!.status == FileStatus.PENDING_UPLOAD) {
            rethrow;
          }
        }
        _assertRunning(epoch, cancel);
        _checkFile(flow, flow.status!);
      }
      final deadline = _now().add(const Duration(minutes: 2));
      var polls = 0;
      _step(UploadStep.processing);
      while (flow.status!.status == FileStatus.PROCESSING && polls < 60 && _now().isBefore(deadline)) {
        polls++;
        await wait(const Duration(seconds: 2), cancel);
        _assertRunning(epoch, cancel);
        flow.status = await files.status(flow.intent!.fileId, cancel: cancel);
        _assertRunning(epoch, cancel);
        _checkFile(flow, flow.status!);
      }
      if (flow.status!.status == FileStatus.PROCESSING) {
        throw ApiError(status: 0, code: 'UPLOAD_PROCESSING_TIMEOUT');
      }
      if (flow.status!.status != FileStatus.READY) {
        throw ApiError(status: 409, code: flow.status!.errorCode ?? 'UPLOAD_FAILED');
      }
      _step(UploadStep.draft);
      ref.invalidate(mentorPrimaryWorkspaceProvider(classId));
      final latestWorkspace = await ref.read(mentorPrimaryWorkspaceProvider(classId).future);
      _assertRunning(epoch, cancel);
      if (latestWorkspace.readonly || !latestWorkspace.authorMaterials) {
        throw ApiError(status: 403, code: 'MATERIAL_ACCESS_DENIED');
      }
      flow.draftMayExist = true;
      MentorMaterialDetail detail;
      try {
        detail = await materials.create(classId, flow.unit, {
          'contentType': flow.status!.kind == FileKind.VIDEO ? 'VIDEO' : 'FILE',
          'title': flow.title,
          'description': flow.description,
          'fileId': flow.intent!.fileId,
        }, cancel: cancel);
      } catch (error) {
        if (!_ambiguous(error)) {
          flow.draftMayExist = false;
        }
        rethrow;
      }
      _assertRunning(epoch, cancel);
      _finish(flow, detail);
      return true;
    } catch (error) {
      if (!_valid(epoch)) {
        return false;
      }
      if (error is ApiError && error.code == 'UPLOAD_URL_EXPIRED' && !flow.transferred) {
        flow.intent = null;
      }
      state = state.copy(
        busy: false,
        error: error,
        canRetry: !{FileStatus.FAILED, FileStatus.DELETED}.contains(flow.status?.status),
        requiresVerification: flow.draftMayExist,
      );
      return false;
    }
  }
}
