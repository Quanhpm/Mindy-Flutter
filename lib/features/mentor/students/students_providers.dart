import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/session/session_controller.dart';
import '../classes/classes_providers.dart';
import '../reports/reports_api.dart';
import '../reports/reports_models.dart';
import '../reports/reports_providers.dart';
import 'students_api.dart';
import 'students_models.dart';

final mentorStudentsProvider = FutureProvider.autoDispose.family<MentorStudentsData, String>((ref, id) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final api = ref.watch(mentorStudentsApiProvider);
  final workspace = await ref.watch(mentorPrimaryWorkspaceProvider(id).future);
  if (!workspace.readRoster || !workspace.readReports) {
    throw ApiError(status: 403, code: 'MENTOR_SCOPE_REQUIRED');
  }
  if (!ref.mounted) {
    throw ApiError(status: 0, code: 'REQUEST_CANCELLED');
  }
  final summaryFuture = ref.watch(mentorClassAttendanceSummaryProvider(id).future);
  final results = await Future.wait<Object>([api.all(id, cancel: cancel), summaryFuture]);
  final roster = results[0] as List<MentorStudent>;
  final summary = results[1] as ClassAttendanceSummary;
  final byId = {for (final row in summary.items) row.enrollmentId: row};
  final rows = <MentorStudentRow>[];
  for (final student in roster) {
    final attendance = byId[student.enrollmentId];
    if (attendance == null || attendance.student.id != student.studentId) {
      throw ApiError.invalidResponse(MentorStudentsApi.errorCode);
    }
    rows.add(MentorStudentRow(student: student, counts: attendance.counts));
  }
  return MentorStudentsData(workspace: workspace, rows: rows);
});

typedef MentorStudentQuery = ({String classId, String studentId});
final mentorStudentDetailsProvider = FutureProvider.autoDispose.family<MentorStudentDetails, MentorStudentQuery>((
  ref,
  query,
) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final reports = ref.watch(mentorReportsApiProvider), students = ref.watch(mentorStudentsApiProvider);
  final workspace = await ref.watch(mentorPrimaryWorkspaceProvider(query.classId).future);
  if (!workspace.readRoster || !workspace.readReports) {
    throw ApiError(status: 403, code: 'MENTOR_SCOPE_REQUIRED');
  }
  final results = await Future.wait<Object>([
    reports.studentSummary(query.classId, query.studentId, cancel: cancel),
    reports.history(query.classId, query.studentId, cancel: cancel),
    students.progress(query.classId, query.studentId, cancel: cancel),
  ]);
  final summary = results[0] as StudentAttendanceSummary;
  final history = results[1] as StudentAttendanceHistory;
  final progress = results[2] as StudentStoredProgress;
  if (!ref.mounted) {
    throw ApiError(status: 0, code: 'REQUEST_CANCELLED');
  }
  final units = await ref.watch(mentorClassUnitsProvider(query.classId).future);
  if (summary.timeZone != workspace.timeZone ||
      history.timeZone != workspace.timeZone ||
      progress.timeZone != workspace.timeZone) {
    throw ApiError.invalidResponse(MentorReportsApi.errorCode);
  }
  return MentorStudentDetails(summary: summary, history: history, progress: progress, units: units);
});
