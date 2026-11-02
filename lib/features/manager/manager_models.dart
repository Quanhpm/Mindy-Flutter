// ignore_for_file: constant_identifier_names
import '../../core/network/json.dart';
import '../../core/utils/format.dart';
import '../courses/courses_models.dart';
import '../mentor/schedule/schedule_models.dart';
import '../my_classes/my_classes_models.dart';

const managerErrorCode = 'INVALID_MANAGER_RESPONSE';
int managerMoney(Json j, String key) {
  final v = j.integer(key);
  if (v < 0 || v > 9007199254740991) j.fail();
  return v;
}

int positive(Json j, String key) {
  final v = j.integer(key);
  if (v < 1) j.fail();
  return v;
}

int countValue(Json j, String key) {
  final v = j.integer(key);
  if (v < 0) j.fail();
  return v;
}

String managerZone(Json j) {
  final z = j.nonEmpty('timeZone');
  if (!Dates.isValidZone(z)) j.fail();
  return z;
}

class ManagerPerson {
  const ManagerPerson({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.active,
  });
  final String id, name, email, role;
  final String? phone;
  final bool active;
  factory ManagerPerson.fromJson(Json j) {
    final role = j.str('role'), status = j.str('status');
    if (!['MENTOR', 'STUDENT'].contains(role) || !['ACTIVE', 'SUSPENDED'].contains(status)) j.fail();
    return ManagerPerson(
      id: j.uuid('id'),
      name: j.strOrNull('displayName') ?? j.str('email'),
      email: j.str('email'),
      phone: j.strOrNull('phone'),
      role: role,
      active: status == 'ACTIVE',
    );
  }
}

class ManagedCourse {
  const ManagedCourse(this.course, this.units, this.active);
  final Course course;
  final List<ManagedUnit> units;
  final bool active;
  factory ManagedCourse.fromJson(Json j) => ManagedCourse(
    Course.fromJson(j),
    j.has('units') ? List.unmodifiable(j.list('units', ManagedUnit.fromJson)) : const [],
    j.boolean('isActive'),
  );
}

class ManagedUnit {
  const ManagedUnit(this.id, this.title, this.number);
  final String id, title;
  final int number;
  factory ManagedUnit.fromJson(Json j) => ManagedUnit(j.uuid('id'), j.str('title'), positive(j, 'unitNumber'));
}

class ManagedClass {
  const ManagedClass({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    required this.mentor,
    required this.start,
    required this.end,
    required this.courseId,
  });
  final String id, name, code, start, end, courseId;
  final ClassStatus status;
  final TeachingPerson? mentor;
  factory ManagedClass.fromJson(Json j) => ManagedClass(
    id: j.uuid('id'),
    name: j.str('name'),
    code: j.str('code'),
    status: j.enumOf('status', ClassStatus.values),
    mentor: j.objOrNull('mentor') == null ? null : TeachingPerson.fromJson(j.obj('mentor')),
    start: j.day('startDate'),
    end: j.day('endDate'),
    courseId: j.uuid('courseId'),
  );
}

class ManagedClassDetail {
  const ManagedClassDetail(this.info, this.room, this.course, this.units, this.sessions, this.activeStudents);
  final ManagedClass info;
  final String? room;
  final String course;
  final int units, sessions, activeStudents;
  factory ManagedClassDetail.fromJson(Json j) => ManagedClassDetail(
    ManagedClass.fromJson(j),
    j.strOrNull('roomName'),
    j.obj('course').str('title'),
    countValue(j, 'unitCount'),
    countValue(j, 'sessionCount'),
    countValue(j.obj('enrollmentCounts'), 'ACTIVE'),
  );
}

class ManagerStudentClass {
  const ManagerStudentClass(this.id, this.classId, this.name, this.enrollment, this.payment, this.orderId);
  final String id, classId, name, orderId;
  final EnrollmentStatus enrollment;
  final String payment;
  factory ManagerStudentClass.fromJson(Json j) {
    final payment = j.str('paymentType');
    if (!['CASH', 'PAYOS'].contains(payment)) j.fail();
    return ManagerStudentClass(
      j.uuid('enrollmentId'),
      j.obj('class').uuid('id'),
      j.obj('class').str('name'),
      j.enumOf('enrollmentStatus', EnrollmentStatus.values),
      payment,
      j.uuid('orderId'),
    );
  }
}
