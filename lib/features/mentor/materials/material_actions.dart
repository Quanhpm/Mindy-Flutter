import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/await_provider.dart';
import '../classes/classes_providers.dart';
import 'materials_api.dart';
import 'materials_models.dart';
import 'materials_providers.dart';

enum MaterialCommandKind { edit, submit, delete }

class MaterialActionState {
  const MaterialActionState({
    this.busy = false,
    this.checkRequired = false,
    this.reloadOnly = false,
    this.error,
    this.changed = 0,
    this.total = 0,
  });
  final bool busy, checkRequired, reloadOnly;
  final Object? error;
  final int changed, total;
  bool get locked => busy || checkRequired || reloadOnly;
}

class _Command {
  const _Command(this.kind, this.material, {this.title, this.description});
  final MaterialCommandKind kind;
  final MentorMaterial material;
  final String? title, description;
}

final materialActionsProvider = NotifierProvider.autoDispose.family<MaterialActions, MaterialActionState, String>(
  MaterialActions.new,
);

/// Một lệnh tại một thời điểm; kết quả chưa rõ chỉ được kiểm tra bằng GET.
/// Bulk dừng ở lỗi đầu tiên. Những lệnh chưa gửi cần chọn lại từ danh sách mới.
class MaterialActions extends Notifier<MaterialActionState> {
  MaterialActions(this.classId);
  final String classId;
  _Command? _pending;
  void Function()? _release;
  @override
  MaterialActionState build() {
    ref.watch(sessionEpochProvider);
    _pending = null;
    _release?.call();
    _release = null;
    return const MaterialActionState();
  }

  bool _valid(int epoch) => ref.mounted && ref.read(sessionEpochProvider) == epoch;
  void _hold() {
    _release ??= ref.keepAlive().close;
  }

  void _unhold() {
    _release?.call();
    _release = null;
  }

  bool _ambiguous(Object error) =>
      error is! ApiError || error.status == 0 || error.status == 408 || error.status >= 500;
  Future<void> _guard(_Command command, int epoch) async {
    ref.invalidate(mentorPrimaryWorkspaceProvider(classId));
    final workspace = await awaitProvider(ref, mentorPrimaryWorkspaceProvider(classId).future);
    if (!_valid(epoch)) {
      throw ApiError(status: 0, code: 'REQUEST_CANCELLED');
    }
    final actor = ref.read(sessionProvider).user;
    if (workspace.readonly ||
        !workspace.authorMaterials ||
        actor == null ||
        !command.material.ownEditable(actor.id, classId)) {
      throw ApiError(status: 403, code: 'MATERIAL_ACCESS_DENIED');
    }
    if (command.kind == MaterialCommandKind.submit && command.material.reviewStatus != MaterialReviewStatus.DRAFT) {
      throw ApiError(status: 409, code: 'MATERIAL_NEEDS_EDIT');
    }
  }

  Future<void> _reload(int epoch) async {
    if (!_valid(epoch)) {
      return;
    }
    ref.invalidate(mentorPrimaryWorkspaceProvider(classId));
    ref.invalidate(mentorMaterialsProvider(classId));
    await awaitProvider(ref, mentorMaterialsProvider(classId).future);
  }

  Future<bool> edit(MentorMaterial material, {required String title, String? description}) =>
      _run([_Command(MaterialCommandKind.edit, material, title: title.trim(), description: description?.trim())]);
  Future<bool> submit(List<MentorMaterial> materials) =>
      _run([for (final material in materials) _Command(MaterialCommandKind.submit, material)]);
  Future<bool> delete(MentorMaterial material) => _run([_Command(MaterialCommandKind.delete, material)]);
  void clearIssue() {
    if (!state.locked) {
      state = MaterialActionState(changed: state.changed, total: state.total);
    }
  }

  Future<bool> _run(List<_Command> commands) async {
    if (state.locked || commands.isEmpty) {
      return false;
    }
    final epoch = ref.read(sessionEpochProvider), api = ref.read(mentorMaterialsApiProvider);
    state = MaterialActionState(busy: true, total: commands.length);
    _hold();
    var changed = 0;
    var allAcknowledged = false;
    try {
      for (final command in commands) {
        if (command.kind == MaterialCommandKind.edit &&
            ((command.title?.isEmpty ?? true) ||
                command.title!.length > 250 ||
                (command.description?.length ?? 0) > 5000)) {
          throw ApiError(status: 422, code: 'MATERIAL_INPUT_INVALID');
        }
        await _guard(command, epoch);
        if (!_valid(epoch)) {
          return false;
        }
        _pending = command;
        try {
          switch (command.kind) {
            case MaterialCommandKind.edit:
              final result = await api.patch(
                classId,
                command.material,
                title: command.title!,
                description: command.description,
              );
              if (result.material.revision != command.material.revision + 1) {
                throw ApiError.invalidResponse(MentorMaterialsApi.errorCode);
              }
            case MaterialCommandKind.submit:
              final result = await api.submit(classId, command.material);
              if (result.material.revision != command.material.revision ||
                  result.material.reviewStatus != MaterialReviewStatus.PENDING_REVIEW) {
                throw ApiError.invalidResponse(MentorMaterialsApi.errorCode);
              }
            case MaterialCommandKind.delete:
              await api.delete(classId, command.material);
          }
        } catch (error) {
          if (!_ambiguous(error)) {
            _pending = null;
          }
          rethrow;
        }
        if (!_valid(epoch)) {
          return false;
        }
        _pending = null;
        changed++;
        state = MaterialActionState(busy: true, changed: changed, total: commands.length);
      }
      allAcknowledged = true;
      await _reload(epoch);
      if (!_valid(epoch)) {
        return false;
      }
      state = MaterialActionState(changed: changed, total: commands.length);
      _unhold();
      return true;
    } catch (error) {
      if (!_valid(epoch)) {
        return false;
      }
      var reloadOnly = allAcknowledged;
      if (_pending == null && !allAcknowledged) {
        try {
          await _reload(epoch);
        } catch (_) {
          reloadOnly = true;
        }
      }
      if (!_valid(epoch)) {
        return false;
      }
      state = MaterialActionState(
        error: error,
        checkRequired: _pending != null,
        reloadOnly: reloadOnly,
        changed: changed,
        total: commands.length,
      );
      if (!state.locked) {
        _unhold();
      }
      return false;
    }
  }

  /// Sau ack/reload lỗi chỉ GET. Sau lỗi mutation, xác minh kết quả rồi bỏ phần bulk
  /// chưa gửi; không lặp lại PATCH/POST/DELETE từ nút kiểm tra này.
  Future<bool> check() async {
    if (state.busy || (!state.checkRequired && !state.reloadOnly)) {
      return false;
    }
    final before = state,
        epoch = ref.read(sessionEpochProvider),
        api = ref.read(mentorMaterialsApiProvider),
        command = _pending;
    state = MaterialActionState(busy: true, changed: before.changed, total: before.total);
    var changed = before.changed;
    Object? issue;
    try {
      if (command != null) {
        MentorMaterial? current;
        try {
          current = (await api.detail(classId, command.material.id)).material;
        } catch (error) {
          if (error is! ApiError || error.status != 404 || error.code != 'MATERIAL_NOT_FOUND') {
            rethrow;
          }
          if (command.kind != MaterialCommandKind.delete) {
            issue = error;
          }
        }
        if (!_valid(epoch)) {
          return false;
        }
        final applied = switch (command.kind) {
          MaterialCommandKind.delete => current == null,
          MaterialCommandKind.edit =>
            current != null &&
                current.revision > command.material.revision &&
                current.title == command.title &&
                current.description == command.description,
          MaterialCommandKind.submit =>
            current != null &&
                current.revision == command.material.revision &&
                current.reviewStatus != MaterialReviewStatus.DRAFT,
        };
        if (applied) {
          changed++;
        } else {
          issue ??= ApiError(status: 409, code: 'MATERIAL_RESULT_UNCONFIRMED');
        }
        _pending = null;
      }
      await _reload(epoch);
      if (!_valid(epoch)) {
        return false;
      }
      state = MaterialActionState(error: issue, changed: changed, total: before.total);
      _unhold();
      return issue == null;
    } catch (error) {
      if (!_valid(epoch)) {
        return false;
      }
      state = MaterialActionState(
        error: error,
        checkRequired: _pending != null,
        reloadOnly: _pending == null,
        changed: changed,
        total: before.total,
      );
      return false;
    }
  }
}
