// ignore_for_file: constant_identifier_names
import '../../../core/network/json.dart';
import '../../courses/courses_models.dart';
import '../schedule/schedule_models.dart';

enum MentorClassStatus { DRAFT, OPEN, IN_PROGRESS, COMPLETED, CANCELLED }

enum MentorClassAssignment { PRIMARY, SUBSTITUTE, BOTH }

enum MentorClassFilter { PRIMARY, SUBSTITUTE, ANY }

enum MentorClassScope { CLASS, SESSION }

class MentorClass {
  const MentorClass({
    required this.id,
    required this.courseId,
    required this.code,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.mode,
    required this.maxStudents,
    required this.availableSeats,
    required this.mentor,
    required this.status,
    required this.assignment,
    required this.scope,
  });
  final String id, courseId, code, name, startDate, endDate;
  final DeliveryMode mode;
  final int maxStudents, availableSeats;
  final TeachingPerson mentor;
  final MentorClassStatus status;
  final MentorClassAssignment assignment;
  final MentorClassScope scope;

  factory MentorClass.fromJson(Json j) {
    final max = j.integer('maxStudents'), seats = j.integer('availableSeats');
    final start = j.day('startDate'), end = j.day('endDate');
    if (max < 1 || seats < 0 || seats > max || start.compareTo(end) > 0) j.fail();
    final assignment = j.enumOf('assignmentType', MentorClassAssignment.values);
    final scope = j.enumOf('accessScope', MentorClassScope.values);
    if ((assignment == MentorClassAssignment.SUBSTITUTE) != (scope == MentorClassScope.SESSION)) j.fail();
    return MentorClass(
      id: j.uuid('id'),
      courseId: j.uuid('courseId'),
      code: j.nonEmpty('code'),
      name: j.nonEmpty('name'),
      startDate: start,
      endDate: end,
      mode: j.enumOf('deliveryMode', DeliveryMode.values),
      maxStudents: max,
      availableSeats: seats,
      mentor: TeachingPerson.fromJson(j.obj('mentor')),
      status: j.enumOf('status', MentorClassStatus.values),
      assignment: assignment,
      scope: scope,
    );
  }
}
