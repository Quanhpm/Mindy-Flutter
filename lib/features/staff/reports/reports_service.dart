import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../shared/remote.dart';
import 'reports_models.dart';

final staffReportsServiceProvider = Provider(
  (ref) => StaffReportsService(ref.watch(apiClientProvider)),
);

class StaffReportsService {
  StaffReportsService(this.api);
  final ApiClient api;
  Future<ReportData> read(ReportRequest r, {int page = 1}) async {
    try {
      final root = r.manager
          ? 'management/classes/${resourceId(r.classId)}'
          : 'mentor/classes/${resourceId(r.classId)}';
      final student = r.studentId == null
          ? root
          : '$root/students/${resourceId(r.studentId)}';
      final suffix = switch (r.kind) {
        ReportKind.attendance => 'attendance-summary',
        ReportKind.progress => 'progress',
        ReportKind.studentSummary => 'attendance-summary',
        ReportKind.history => 'attendance',
        ReportKind.units => 'progress',
      };
      final path = '${r.studentId == null ? root : student}/$suffix',
          paged = r.kind != ReportKind.studentSummary;
      final j = Json(
        await api.get(
          path,
          query: {
            if (paged) 'page': page,
            if (paged) 'pageSize': 20,
            if ([
              ReportKind.attendance,
              ReportKind.studentSummary,
              ReportKind.history,
            ].contains(r.kind))
              ...reportRangeQuery(r.range),
          },
        ),
        'INVALID_REPORT_RESPONSE',
      );
      if ([
            ReportKind.attendance,
            ReportKind.studentSummary,
            ReportKind.history,
          ].contains(r.kind) &&
          j.uuid('classId') != r.classId) {
        j.fail();
      }
      if (paged &&
          (j.integer('page') != page ||
              j.integer('pageSize') != 20 ||
              j.integer('total') < 0)) {
        j.fail();
      }
      if ([ReportKind.progress, ReportKind.units].contains(r.kind) &&
          j.str('completionPolicy') != 'UNDEFINED') {
        j.fail();
      }
      if (r.kind == ReportKind.studentSummary &&
          j.str('aggregationScope') != 'STUDENT_CLASS_HISTORY') {
        j.fail();
      }
      return ReportData(
        enrollments: r.kind == ReportKind.attendance
            ? j.list('items', ReportEnrollment.new)
            : const [],
        history: r.kind == ReportKind.history
            ? j.list('items', ReportHistory.new)
            : const [],
        progress: r.kind == ReportKind.progress
            ? j.list('items', ReportProgress.new)
            : const [],
        units: r.kind == ReportKind.units
            ? j.list('items', ReportUnit.new)
            : const [],
        summary: r.kind == ReportKind.studentSummary ? ReportCounts(j) : null,
        total: paged ? j.integer('total') : 0,
        page: page,
        readonly: j.has('readonly') ? j.boolean('readonly') : false,
        asOf: j.dateTime('asOf'),
        timeZone: j.nonEmpty('timeZone'),
      );
    } catch (e) {
      throw RemoteError.from(e);
    }
  }

  Future<Map<String, String>> unitNames(String classId) async {
    try {
      final j = Json(
        await api.get(
          'mentor/classes/${resourceId(classId)}/units',
          query: {'page': 1, 'pageSize': 100},
        ),
      );
      return {
        for (final u in j.list(
          'items',
          (j) => (id: j.uuid('id'), title: j.str('title')),
        ))
          u.id: u.title,
      };
    } catch (_) {
      return {};
    }
  }
}
