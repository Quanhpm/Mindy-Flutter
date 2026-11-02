import '../../../core/network/json.dart';
import '../../mentor/operations/operations_models.dart';
import '../manager_models.dart';

class ManagerLeave {
  const ManagerLeave(this.request, this.mentorId);
  final LeaveRequest request;
  final String mentorId;
  factory ManagerLeave.fromJson(Json j) => ManagerLeave(LeaveRequest.fromJson(j), j.uuid('mentorId'));
}

class StudentLeaveConflict {
  const StudentLeaveConflict(this.sourceId, this.studentId, this.conflictingId);
  final String sourceId, studentId, conflictingId;
  factory StudentLeaveConflict.fromJson(Json j) =>
      StudentLeaveConflict(j.uuid('sourceSessionId'), j.uuid('studentId'), j.uuid('conflictingSessionId'));
}

class ManagerLeaveDetail {
  const ManagerLeaveDetail(this.header, this.items, this.conflicts, this.sourcesCurrent, this.conflictCount);
  final ManagerLeave header;
  final List<LeaveItem> items;
  final List<StudentLeaveConflict> conflicts;
  final bool sourcesCurrent;
  final int conflictCount;
  factory ManagerLeaveDetail.fromJson(Json j) => ManagerLeaveDetail(
    ManagerLeave.fromJson(j),
    List.unmodifiable(j.list('items', LeaveItem.fromJson)),
    List.unmodifiable(j.list('studentConflicts', StudentLeaveConflict.fromJson)),
    j.boolean('sourcesCurrent'),
    countValue(j, 'studentConflictCount'),
  );
  bool get canApprove =>
      header.request.status == LeaveStatus.PENDING &&
      sourcesCurrent &&
      (header.request.period == LeavePeriod.FULL_DAY || conflictCount == 0);
}

class ManagerLeaveDecision {
  const ManagerLeaveDecision(this.request);
  final LeaveRequest request;
  factory ManagerLeaveDecision.fromJson(Json j) =>
      ManagerLeaveDecision(LeaveRequest.fromJson(j.has('request') ? j.obj('request') : j));
}

typedef ManagerLeaveFilter = ({LeaveStatus? status, String? mentorId});
