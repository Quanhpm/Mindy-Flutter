import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/concurrent.dart';
import '../attendance/attendance_api.dart';
import '../classes/classes_models.dart';
import '../classes/classes_providers.dart';
import '../schedule/schedule_models.dart';
import 'reports_api.dart';
import 'reports_models.dart';

final mentorClassAttendanceSummaryProvider = FutureProvider.autoDispose.family<ClassAttendanceSummary, String>((
  ref,
  id,
) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final api = ref.watch(mentorReportsApiProvider);
  final workspace = await ref.watch(mentorPrimaryWorkspaceProvider(id).future);
  if (!workspace.readReports) {
    throw ApiError(status: 403, code: 'MENTOR_SCOPE_REQUIRED');
  }
  final summary = await api.classSummary(id, cancel: cancel);
  if (summary.timeZone != workspace.timeZone) {
    throw ApiError.invalidResponse(MentorReportsApi.errorCode);
  }
  return summary;
});

final mentorClassReportProvider = FutureProvider.autoDispose.family<MentorClassReport, String>((ref, id) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final api = ref.watch(mentorAttendanceApiProvider);
  final workspace = await ref.watch(mentorPrimaryWorkspaceProvider(id).future);
  if (!ref.mounted) {
    throw ApiError(status: 0, code: 'REQUEST_CANCELLED');
  }
  if (!workspace.readReports) {
    throw ApiError(status: 403, code: 'MENTOR_SCOPE_REQUIRED');
  }
  final summary = await ref.watch(mentorClassAttendanceSummaryProvider(id).future);
  if (!ref.mounted) {
    throw ApiError(status: 0, code: 'REQUEST_CANCELLED');
  }
  final sessions = await ref.watch(mentorWorkspaceSessionsProvider(id).future);
  final completed = sessions.where((row) => row.session.status == TeachingStatus.COMPLETED).toList()
    ..sort((a, b) => b.session.startsAt.compareTo(a.session.startsAt));
  final rows = await mapConcurrent<MentorWorkspaceSession, SessionAttendanceReport>(completed, (row) async {
    if (!row.readContext) {
      return SessionAttendanceReport(row: row, denied: true);
    }
    try {
      final roster = await api.roster(row.session.id, cancel: cancel);
      if (roster.header.session.classId != id || roster.header.session.status != TeachingStatus.COMPLETED) {
        throw ApiError(status: 409, code: 'SESSION_STATE_CONFLICT');
      }
      return SessionAttendanceReport(
        row: MentorWorkspaceSession(
          session: roster.header.session,
          readContext: row.readContext,
          writeNotes: row.writeNotes,
        ),
        totals: roster.header.totals,
      );
    } catch (error) {
      return SessionAttendanceReport(row: row, error: error, denied: error is ApiError && error.status == 403);
    }
  });
  return MentorClassReport(workspace: workspace, summary: summary, sessions: rows);
});
