import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/session/session_user.dart';

String mgId(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final mgActor = mgId(1),
    mgMentor = mgId(2),
    mgStudent = mgId(3),
    mgCourse = mgId(4),
    mgUnit = mgId(5),
    mgClass = mgId(6),
    mgSession = mgId(8),
    mgTarget = mgId(9),
    mgLeave = mgId(10),
    mgMaterial = mgId(11),
    mgOrder = mgId(13),
    mgConflict = mgId(14),
    mgDraft = mgId(16);
const mgNow = '2026-11-02T07:15:00Z', mgZone = 'Asia/Ho_Chi_Minh';
Map<String, Object?> mgPerson(String role, {String? id}) => {
  'id':
      id ??
      (role == 'MANAGER'
          ? mgActor
          : role == 'MENTOR'
          ? mgMentor
          : mgStudent),
  'email': '${role.toLowerCase()}@example.test',
  'displayName': role == 'MANAGER'
      ? 'Quản lý tổng hợp'
      : role == 'MENTOR'
      ? 'Giảng viên tổng hợp'
      : 'Học viên tổng hợp',
  'phone': null,
  'role': role,
  'status': 'ACTIVE',
  'createdAt': mgNow,
};
Map<String, Object?> mgClassJson([String? id]) => {
  'id': id ?? mgClass,
  'courseId': mgCourse,
  'code': 'SYNTHETIC',
  'name': id == mgId(18) ? 'Lớp học bù tổng hợp' : 'Lớp lập trình tổng hợp',
  'startDate': '2026-11-01',
  'endDate': '2026-12-20',
  'deliveryMode': 'ONLINE',
  'maxStudents': 30,
  'availableSeats': 20,
  'status': 'IN_PROGRESS',
  'mentor': {'id': mgMentor, 'displayName': 'Giảng viên tổng hợp'},
  'assignmentType': 'PRIMARY',
  'accessScope': 'CLASS',
};
Map<String, Object?> mgSessionJson([String? id]) => {
  'sessionId': id ?? mgSession,
  'classId': id == mgTarget ? mgId(18) : mgClass,
  'classUnitId': id == mgTarget ? mgId(19) : mgId(7),
  'title': 'Chương 1 · Biến và vòng lặp',
  'startsAt': id == mgTarget ? '2026-11-15T07:00:00Z' : '2026-11-12T07:00:00Z',
  'endsAt': id == mgTarget ? '2026-11-15T08:30:00Z' : '2026-11-12T08:30:00Z',
  'status': 'SCHEDULED',
  'primaryMentor': {'id': mgMentor, 'displayName': 'Giảng viên tổng hợp'},
  'effectiveMentor': {'id': mgMentor, 'displayName': 'Giảng viên tổng hợp'},
  'assignmentType': 'PRIMARY',
  'version': 2,
  'timeZone': mgZone,
  'asOf': mgNow,
  'actualStartedAt': null,
  'actualEndedAt': null,
  'editableUntil': null,
  'makeupForSessionId': null,
  'makeupRootSessionId': null,
};
Map<String, Object?> mgCourseJson({bool detail = false}) => {
  'id': mgCourse,
  'code': 'SYNTHETIC',
  'title': 'Lập trình nhập môn',
  'description': 'Khóa học tổng hợp để kiểm tra.',
  'imgUrl': null,
  'priceAmount': 1000000,
  'category': {'id': mgId(40), 'name': 'Lập trình', 'slug': 'synthetic'},
  'isActive': true,
  'createdAt': mgNow,
  'updatedAt': mgNow,
  if (detail)
    'units': [
      {
        'id': mgUnit,
        'unitNumber': 1,
        'title': 'Biến và vòng lặp',
        'description': null,
        'requiredScorePercent': 80,
      },
    ],
};
Map<String, Object?> mgMaterialJson({bool draft = false, int revision = 1}) => {
  'id': draft ? mgDraft : mgMaterial,
  'courseUnitId': mgUnit,
  'contentType': 'ARTICLE',
  'title': draft ? 'Bản nháp Manager' : 'Bài viết cần duyệt',
  'description': 'Tài liệu tổng hợp.',
  'sortOrder': 0,
  'availableAt': null,
  'sessionId': null,
  'createdBy': draft ? mgActor : mgMentor,
  'createdInClassId': draft ? null : mgClass,
  'revision': revision,
  'reviewStatus': draft ? 'DRAFT' : 'PENDING_REVIEW',
  'approvedRevision': null,
  'reviewedBy': null,
  'reviewedAt': null,
  'firstApprovedAt': null,
  'rejectionReason': null,
  'publishedAt': null,
  'createdAt': mgNow,
  'updatedAt': mgNow,
  'canEdit': draft,
  'file': null,
  'contentHtml': '<p>Nội dung <strong>giữ nguyên định dạng</strong>.</p>',
  'contentSchemaVersion': 1,
  'inlineImages': [],
  'attachments': [],
};
Map<String, Object?> mgLeaveJson({
  int version = 1,
  String status = 'PENDING',
}) => {
  'id': mgLeave,
  'mentorId': mgMentor,
  'fromDate': '2026-11-12',
  'toDate': '2026-11-12',
  'period': 'FULL_DAY',
  'reason': 'Công tác, đề xuất dạy bù cho đủ buổi.',
  'status': status,
  'version': version,
  'submittedAt': mgNow,
  'expiresAt': '2026-11-12T07:00:00Z',
  'itemCount': 1,
  'items': [
    {
      'sourceSessionId': mgSession,
      'classId': mgClass,
      'sourceVersion': 2,
      'sourceStartsAt': '2026-11-12T07:00:00Z',
      'sourceEndsAt': '2026-11-12T08:30:00Z',
      'startsAt': '2026-11-15T07:00:00Z',
      'endsAt': '2026-11-15T08:30:00Z',
      'replacementSessionId': null,
    },
  ],
  'page': 1,
  'pageSize': 100,
  'classExtensions': [
    {'classId': mgClass, 'endDate': '2026-12-20'},
  ],
  'review': null,
  'asOf': mgNow,
  'timeZone': mgZone,
  'studentConflictCount': 1,
  'studentConflicts': [
    {
      'sourceSessionId': mgSession,
      'studentId': mgStudent,
      'conflictingSessionId': mgTarget,
    },
  ],
  'sourcesCurrent': true,
};
Map<String, Object?> mgOrderJson({bool paid = false}) => {
  'id': mgOrder,
  'orderCode': 'MINDY-SYNTHETIC',
  'totalAmount': 1000000,
  'paymentType': 'CASH',
  'status': paid ? 'PAID' : 'PENDING',
  'expiresAt': '2026-11-20T07:00:00Z',
  'paidAt': paid ? mgNow : null,
  'createdAt': mgNow,
  'student': {'id': mgStudent, 'displayName': 'Học viên tổng hợp'},
  'mentorId': mgMentor,
  'payment': paid
      ? {
          'id': mgId(32),
          'orderId': mgOrder,
          'amount': 1000000,
          'status': 'SUCCEEDED',
          'paidAt': mgNow,
          'confirmedBy': {
            'id': mgActor,
            'displayName': 'Quản lý tổng hợp',
            'source': 'MANAGER',
          },
          'review': null,
        }
      : null,
  'details': [
    {
      'id': mgId(33),
      'classId': mgClass,
      'className': 'Lớp lập trình tổng hợp',
      'courseTitle': 'Lập trình nhập môn',
      'priceAmount': 1000000,
      'quantity': 1,
      'totalAmount': 1000000,
    },
  ],
};
Map<String, Object?> mgConflictJson({
  String status = 'OPEN',
  int version = 1,
}) => {
  'id': mgConflict,
  'enrollmentId': mgId(31),
  'student': {'id': mgStudent, 'displayName': 'Học viên tổng hợp'},
  'sourceSession': mgSessionJson(),
  'conflictingIntervals': [
    {
      'sessionId': mgTarget,
      'startsAt': '2026-11-15T07:00:00Z',
      'endsAt': '2026-11-15T08:30:00Z',
    },
  ],
  'status': status,
  'version': version,
  'makeupPlacementId': status == 'MAKEUP_ASSIGNED' ? mgId(15) : null,
  'makeupPlacementVersion': status == 'MAKEUP_ASSIGNED' ? 1 : null,
};
Map<String, Object?> mgPlacementJson({bool cancelled = false}) => {
  'id': mgId(15),
  'conflictId': mgConflict,
  'enrollmentId': mgId(31),
  'sourceClassId': mgClass,
  'sourceSessionId': mgSession,
  'sourceRootSessionId': mgSession,
  'targetSession': mgSessionJson(mgTarget),
  'status': cancelled ? 'CANCELLED' : 'ASSIGNED',
  'version': cancelled ? 2 : 1,
  'attendanceStatus': null,
  'creditStatus': 'PENDING',
};

class ManagerFixtureSession extends SessionController {
  @override
  SessionState build() => SessionState(
    ready: true,
    epoch: 1,
    user: SessionUser.fromJson(Json(mgPerson('MANAGER'))),
  );
  void change() {
    ref.read(apiClientProvider).sessionEpoch++;
    state = SessionState(
      ready: true,
      epoch: state.epoch + 1,
      user: SessionUser.fromJson(
        Json({...mgPerson('MANAGER'), 'id': mgId(90)}),
      ),
    );
  }
}

// Fixture không có client mạng: mọi path không đăng ký đều trả lỗi 501.
class ManagerFixtureAdapter implements HttpClientAdapter {
  final requests =
      <
        ({
          String method,
          String path,
          Object? body,
          Map<String, dynamic> query,
          Map<String, dynamic> headers,
        })
      >[];
  final materials = <String, Map<String, Object?>>{
    mgMaterial: mgMaterialJson(),
    mgDraft: mgMaterialJson(draft: true),
  };
  String leaveStatus = 'PENDING', conflictStatus = 'OPEN';
  int leaveVersion = 1,
      conflictVersion = 1,
      classVersion = 3,
      sessionVersion = 2;
  bool cashPaid = false, loggedIn = true, loseNextWrite = false;
  String? conflictNextPath;
  bool failPaidDetail = false;
  Completer<void>? heldReadGate;
  Object? Function(RequestOptions)? readOverride;
  Completer<ResponseBody>? heldResponse;
  final receipts = <String, Object?>{};
  ResponseBody response(Object? body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  Map<String, Object?> page(
    RequestOptions o,
    List<Map<String, Object?>> rows, {
    Map<String, Object?> meta = const {},
  }) {
    final n = o.queryParameters['page'] as int? ?? 1,
        size = o.queryParameters['pageSize'] as int? ?? 100;
    return {
      'items': rows.skip((n - 1) * size).take(size).toList(),
      'page': n,
      'pageSize': size,
      'total': rows.length,
      ...meta,
    };
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      method: o.method,
      path: o.path,
      body: o.data,
      query: Map.of(o.queryParameters),
      headers: Map.of(o.headers),
    ));
    if (o.method == 'GET' && heldReadGate != null) await heldReadGate!.future;
    if (heldResponse != null && o.method != 'GET') {
      final held = heldResponse!;
      heldResponse = null;
      return held.future;
    }
    if (conflictNextPath == o.path && o.method != 'GET') {
      conflictNextPath = null;
      return response({
        'statusCode': 409,
        'code': 'LEAVE_VERSION_CONFLICT',
        'message': 'Synthetic conflict',
      }, 409);
    }
    if (o.path == 'auth/me') {
      return loggedIn
          ? response(mgPerson('MANAGER'))
          : response({
              'statusCode': 401,
              'code': 'AUTHENTICATION_REQUIRED',
              'message': 'Synthetic',
            }, 401);
    }
    if (o.path == 'auth/login') {
      loggedIn = true;
      return response({
        'user': mgPerson('MANAGER'),
        'accessTokenExpiresAt': '2026-11-02T09:15:00Z',
      });
    }
    if (o.path == 'auth/logout') {
      loggedIn = false;
      return response(null, 204);
    }
    if (o.path == 'auth/refresh') {
      return response({
        'statusCode': 401,
        'code': 'AUTHENTICATION_REQUIRED',
        'message': 'Synthetic',
      }, 401);
    }
    if (o.method == 'GET' &&
        failPaidDetail &&
        cashPaid &&
        o.path == 'manager/orders/$mgOrder') {
      failPaidDetail = false;
      throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      );
    }
    final data = (o.method == 'GET' ? readOverride?.call(o) : null) ?? _read(o);
    if (data != null) return response(data);
    if (o.method != 'GET') {
      final key = o.headers['Idempotency-Key'] as String?;
      if (key != null && receipts.containsKey(key)) {
        return response(receipts[key]);
      }
      final result = _write(o);
      if (result != null) {
        if (key != null) receipts[key] = result;
        if (loseNextWrite) {
          loseNextWrite = false;
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
        }
        return response(result, o.method == 'DELETE' ? 204 : 200);
      }
    }
    return response({
      'statusCode': 501,
      'code': 'FIXTURE_ROUTE_DISABLED',
      'message': 'Synthetic route disabled',
    }, 501);
  }

  Object? _read(RequestOptions o) {
    if (o.method != 'GET') return null;
    final path = o.path;
    if (path == 'manager/courses') return page(o, [mgCourseJson()]);
    if (path == 'manager/courses/$mgCourse') return mgCourseJson(detail: true);
    if (path == 'manager/mentors' || path == 'manager/students') {
      final role = path.endsWith('mentors') ? 'MENTOR' : 'STUDENT',
          q = (o.queryParameters['q'] as String? ?? '').toLowerCase();
      final person = mgPerson(role);
      return page(
        o,
        q.isEmpty ||
                (person['displayName']! as String).toLowerCase().contains(q)
            ? [person]
            : [],
      );
    }
    if (path.startsWith('manager/mentors/') &&
        !path.endsWith('/classes') &&
        !path.endsWith('/schedule')) {
      return {...mgPerson('MENTOR'), 'id': path.split('/').last};
    }
    if (path.startsWith('manager/students/') && !path.endsWith('/classes')) {
      return {...mgPerson('STUDENT'), 'id': path.split('/').last};
    }
    if (path == 'manager/classes' ||
        path == 'manager/mentors/$mgMentor/classes') {
      return page(o, [mgClassJson()]);
    }
    if (path.startsWith('manager/classes/') && path.endsWith('/units')) {
      return page(o, [
        {
          'id': mgId(7),
          'courseUnitId': mgUnit,
          'title': 'Biến và vòng lặp',
          'position': 1,
          'status': 'OPEN',
          'unlockAt': null,
        },
      ]);
    }
    if (path.startsWith('manager/classes/')) {
      return {
        ...mgClassJson(path.split('/').last),
        'course': {
          'id': mgCourse,
          'title': 'Lập trình nhập môn',
          'code': 'SYNTHETIC',
        },
        'roomName': 'Phòng tổng hợp',
        'unitCount': 1,
        'sessionCount': 1,
        'enrollmentCounts': {
          'ACTIVE': 1,
          'COMPLETED': 0,
          'CANCELLED': 0,
          'PENDING_PAYMENT': 0,
        },
      };
    }
    if (path == 'manager/students/$mgStudent/classes') {
      return page(o, [
        {
          'enrollmentId': mgId(31),
          'enrollmentStatus': 'ACTIVE',
          'registeredAt': mgNow,
          'enrolledAt': mgNow,
          'class': mgClassJson(),
          'orderDetailId': mgId(33),
          'orderId': mgOrder,
          'orderStatus': 'PAID',
          'paymentType': 'CASH',
        },
      ]);
    }
    if (path.startsWith('manager/mentors/') && path.endsWith('/schedule')) {
      return page(
        o,
        [mgSessionJson()],
        meta: {
          'from': o.queryParameters['from'],
          'to': o.queryParameters['to'],
          'timeZone': mgZone,
        },
      );
    }
    if (path == 'manager/materials') {
      final rows = materials.values
          .where(
            (m) =>
                (o.queryParameters['reviewStatus'] == null ||
                    m['reviewStatus'] == o.queryParameters['reviewStatus']) &&
                (o.queryParameters['courseUnitId'] == null ||
                    m['courseUnitId'] == o.queryParameters['courseUnitId']) &&
                (o.queryParameters['contentType'] == null ||
                    m['contentType'] == o.queryParameters['contentType']),
          )
          .toList();
      return page(o, rows);
    }
    if (path.startsWith('manager/materials/')) {
      return materials[path.split('/').last];
    }
    if (path == 'management/mentor-leave-requests') {
      return page(
        o,
        o.queryParameters['status'] == null ||
                o.queryParameters['status'] == leaveStatus
            ? [mgLeaveJson(version: leaveVersion, status: leaveStatus)]
            : [],
        meta: {'asOf': mgNow},
      );
    }
    if (path == 'management/mentor-leave-requests/$mgLeave') {
      return {
        ...mgLeaveJson(version: leaveVersion, status: leaveStatus),
        'page': o.queryParameters['page'] ?? 1,
        'pageSize': o.queryParameters['pageSize'] ?? 100,
      };
    }
    if (path == 'manager/orders') {
      return page(
        o,
        (o.queryParameters['status'] == null ||
                o.queryParameters['status'] == (cashPaid ? 'PAID' : 'PENDING'))
            ? [mgOrderJson(paid: cashPaid)]
            : [],
      );
    }
    if (path == 'manager/orders/$mgOrder') return mgOrderJson(paid: cashPaid);
    if (path == 'management/classes/$mgClass') {
      return {
        'class': {
          'id': mgClass,
          'name': 'Lớp lập trình tổng hợp',
          'code': 'SYNTHETIC',
          'status': 'IN_PROGRESS',
          'primaryMentor': {
            'id': mgMentor,
            'displayName': 'Giảng viên tổng hợp',
          },
          'assignmentVersion': classVersion,
        },
        'sessions': page(o, [
          {...mgSessionJson(), 'version': sessionVersion},
        ]),
      };
    }
    if (path.endsWith('/available-mentors')) {
      return page(
        o,
        [
          {
            'id': mgMentor,
            'displayName': 'Giảng viên tổng hợp',
            'isCurrent': true,
          },
          {
            'id': mgId(20),
            'displayName': 'Giảng viên thay thế',
            'isCurrent': false,
          },
        ],
        meta: {
          'asOf': mgNow,
          'timeZone': mgZone,
          'availabilityBasis': 'TEACHING_SCHEDULE_AND_APPROVED_LEAVE',
          if (path.contains('/class-sessions/')) ...{
            'sessionId': mgSession,
            'sessionVersion': sessionVersion,
            'checkedFrom': '2026-11-12T07:00:00Z',
            'checkedTo': '2026-11-12T08:30:00Z',
          } else ...{
            'classId': mgClass,
            'assignmentVersion': classVersion,
            'affectedSessionCount': 1,
          },
        },
      );
    }
    if (path == 'management/class-sessions/incomplete') {
      return page(
        o,
        [
          {
            'session': {
              ...mgSessionJson(),
              'startsAt': '2026-11-01T07:00:00Z',
              'endsAt': '2026-11-01T08:30:00Z',
            },
            'issue': 'OVERDUE_NOT_STARTED',
            'deadlineExpired': true,
          },
        ],
        meta: {'asOf': mgNow, 'timeZone': mgZone},
      );
    }
    if (path.endsWith('/attendance-summary')) {
      return page(
        o,
        [
          {
            'enrollmentId': mgId(31),
            'student': {'id': mgStudent, 'displayName': 'Học viên tổng hợp'},
            'present': 7,
            'absent': 2,
            'unmarked': 1,
            'excluded': 0,
            'makeupPending': 0,
            'finalizedEligibleCount': 9,
            'rate': 77.78,
          },
        ],
        meta: {'classId': mgClass, 'asOf': mgNow, 'timeZone': mgZone},
      );
    }
    if (path.endsWith('/attendance-audits')) {
      return page(o, [
        {
          'id': mgId(30),
          'attendanceId': mgId(32),
          'enrollmentId': mgId(31),
          'makeupPlacementId': null,
          'entryType': 'REGULAR',
          'actor': {'id': mgMentor, 'displayName': 'Giảng viên tổng hợp'},
          'oldStatus': 'UNMARKED',
          'newStatus': 'PRESENT',
          'reason': 'Điểm danh tổng hợp',
          'occurredAt': mgNow,
          'version': 1,
          'action': 'MARK',
        },
      ]);
    }
    if (path == 'management/student-schedule-conflicts') {
      return page(
        o,
        o.queryParameters['status'] == null ||
                o.queryParameters['status'] == conflictStatus
            ? [mgConflictJson(status: conflictStatus, version: conflictVersion)]
            : [],
        meta: {'asOf': mgNow},
      );
    }
    if (path.endsWith('/makeup-candidates')) {
      return page(
        o,
        [
          {'session': mgSessionJson(mgTarget), 'remainingCapacity': 3},
        ],
        meta: {'asOf': mgNow},
      );
    }
    return null;
  }

  Object? _write(RequestOptions o) {
    final path = o.path,
        body = o.data is Map ? o.data as Map : const <Object?, Object?>{};
    if (path.endsWith('/approve') &&
        path.startsWith('management/mentor-leave')) {
      leaveStatus = 'APPROVED';
      leaveVersion++;
      return {
        'request': mgLeaveJson(status: leaveStatus, version: leaveVersion),
        'replacements': [mgSessionJson(mgTarget)],
        'classExtensions': [],
        'studentConflictCount': 1,
      };
    }
    if (path.endsWith('/reject') &&
        path.startsWith('management/mentor-leave')) {
      leaveStatus = 'REJECTED';
      leaveVersion++;
      return mgLeaveJson(status: leaveStatus, version: leaveVersion);
    }
    if (path == 'manager/cash-orders/$mgOrder/confirm') {
      cashPaid = true;
      return mgOrderJson(paid: true);
    }
    if (path == 'manager/course-units/$mgUnit/materials') {
      final m = {
        ...mgMaterialJson(draft: true),
        'id': mgId(17),
        ...body.cast<String, Object?>(),
      };
      materials[mgId(17)] = m;
      return m;
    }
    if (path.startsWith('manager/materials/')) {
      final parts = path.split('/'), id = parts[2], m = materials[id];
      if (m == null) return null;
      if (o.method == 'PATCH') {
        m.addAll({
          ...body.cast<String, Object?>(),
          'revision': (m['revision']! as int) + 1,
          'reviewStatus': 'DRAFT',
          'approvedRevision': null,
          'publishedAt': null,
        });
        return m;
      }
      if (o.method == 'DELETE') {
        materials.remove(id);
        return <String, Object?>{};
      }
      if (parts.length == 4) {
        final action = parts[3];
        if (action == 'approve') {
          m.addAll({
            'reviewStatus': 'APPROVED',
            'approvedRevision': m['revision'],
            'publishedAt': mgNow,
          });
        }
        if (action == 'reject') {
          m.addAll({
            'reviewStatus': 'REJECTED',
            'rejectionReason': body['reason'],
          });
        }
        if (action == 'publish') m['publishedAt'] = mgNow;
        if (action == 'unpublish') m['publishedAt'] = null;
        return m;
      }
    }
    if (path.endsWith('/mentor') && path.contains('/class-sessions/')) {
      sessionVersion++;
      return {...mgSessionJson(), 'version': sessionVersion};
    }
    if (path.endsWith('/mentor') && path.contains('/classes/')) {
      classVersion++;
      return {
        'classId': mgClass,
        'primaryMentor': {
          'id': body['mentorId'],
          'displayName': 'Giảng viên thay thế',
        },
        'assignmentVersion': classVersion,
        'affectedSessionCount': 1,
        'asOf': mgNow,
      };
    }
    if (path.endsWith('/makeup-placement')) {
      conflictStatus = 'MAKEUP_ASSIGNED';
      conflictVersion++;
      return {
        'placement': mgPlacementJson(),
        'conflictVersion': conflictVersion,
        'targetSessionVersion': 3,
      };
    }
    if (path.endsWith('/cancel') && path.contains('makeup-placements')) {
      conflictStatus = 'OPEN';
      conflictVersion++;
      return mgPlacementJson(cancelled: true);
    }
    return null;
  }

  @override
  void close({bool force = false}) {}
}

ApiClient managerFixtureClient(ManagerFixtureAdapter adapter) =>
    ApiClient(cookieJar: CookieJar())..dio.httpClientAdapter = adapter;
