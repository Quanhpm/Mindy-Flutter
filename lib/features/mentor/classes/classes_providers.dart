import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/network/api_error.dart';
import '../../../core/utils/concurrent.dart';
import '../schedule/schedule_providers.dart';
import '../session/session_context_api.dart';
import '../students/students_api.dart';
import 'classes_api.dart';
import 'classes_models.dart';

final mentorClassesProvider = FutureProvider.autoDispose<List<MentorClass>>((ref) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(mentorClassesApiProvider).all(cancel: cancel);
});

final mentorPrimaryClassesProvider = FutureProvider.autoDispose<List<MentorClass>>((ref) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(mentorClassesApiProvider).all(assignment: MentorClassFilter.PRIMARY, cancel: cancel);
});

final mentorPrimaryWorkspaceProvider = FutureProvider.autoDispose.family<MentorWorkspace, String>((ref, id) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final workspace = await ref.watch(mentorClassesApiProvider).workspace(id, cancel: cancel);
  if (!workspace.primary || !workspace.readClass) {
    throw ApiError(status: 403, code: 'MENTOR_SCOPE_REQUIRED');
  }
  return workspace;
});

final mentorWorkspaceSessionsProvider = FutureProvider.autoDispose.family<List<MentorWorkspaceSession>, String>((
  ref,
  id,
) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final api = ref.watch(mentorClassesApiProvider);
  final workspace = await ref.watch(mentorPrimaryWorkspaceProvider(id).future);
  final sessions = await api.sessions(id, cancel: cancel);
  if (sessions.length != workspace.sessionCount || sessions.any((row) => row.session.timeZone != workspace.timeZone)) {
    throw ApiError.invalidResponse(MentorClassesApi.errorCode);
  }
  return sessions;
});

final mentorClassOverviewProvider = FutureProvider.autoDispose.family<MentorClassOverview, String>((ref, id) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final studentsApi = ref.watch(mentorStudentsApiProvider), roomApi = ref.watch(mentorSessionApiProvider);
  final clock = ref.watch(mentorClockProvider);
  final workspace = await ref.watch(mentorPrimaryWorkspaceProvider(id).future);
  if (!ref.mounted) {
    throw ApiError(status: 0, code: 'REQUEST_CANCELLED');
  }
  final sessions = await ref.watch(mentorWorkspaceSessionsProvider(id).future);
  final count = workspace.readRoster ? await studentsApi.count(id, cancel: cancel) : null;
  final initial = MentorClassOverview(workspace: workspace, sessions: sessions, enrollmentCount: count);
  final next = initial.next(clock());
  String? room;
  Object? roomError;
  var roomKnown = false;
  if (next?.readContext == true) {
    try {
      room = (await roomApi.room(next!.session.id, cancel: cancel)).roomName;
      roomKnown = true;
    } catch (error) {
      roomError = error;
    }
  }
  return MentorClassOverview(
    workspace: workspace,
    sessions: sessions,
    enrollmentCount: count,
    nextRoom: room,
    roomKnown: roomKnown,
    roomError: roomError,
  );
});

final mentorClassUnitsProvider = FutureProvider.autoDispose.family<List<MentorUnit>, String>((ref, id) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final api = ref.watch(mentorClassesApiProvider);
  final workspace = await ref.watch(mentorPrimaryWorkspaceProvider(id).future);
  // Backend từ chối đọc ngữ cảnh tài liệu khi lớp đã hủy.
  if (workspace.status == MentorClassStatus.CANCELLED) {
    return const [];
  }
  final units = await api.units(id, cancel: cancel);
  if (units.length != workspace.unitCount) {
    throw ApiError.invalidResponse(MentorClassesApi.errorCode);
  }
  return units;
});

final mentorClassDetailProvider = FutureProvider.autoDispose.family<MentorClassDetail, String>((ref, id) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final api = ref.watch(mentorClassesApiProvider);
  final overview = await ref.watch(mentorClassOverviewProvider(id).future);
  if (!ref.mounted) {
    throw ApiError(status: 0, code: 'REQUEST_CANCELLED');
  }
  final units = await ref.watch(mentorClassUnitsProvider(id).future);
  final groups = await mapConcurrent(units, (unit) => api.slots(id, unit.id, cancel: cancel));
  final slots = groups.expand((group) => group).toList();
  final byId = {for (final slot in slots) slot.id: slot};
  if (overview.workspace.status != MentorClassStatus.CANCELLED &&
      (byId.length != slots.length ||
          slots.length != overview.sessions.length ||
          overview.sessions.any((row) => byId[row.session.id]?.unitId != row.session.classUnitId))) {
    throw ApiError.invalidResponse(MentorClassesApi.errorCode);
  }
  return MentorClassDetail(overview: overview, units: units, slots: slots);
});
