import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../session/session_controller.dart';
import '../session/session_user.dart';

/// Toàn bộ path của app (tương đương `navigation/routes.ts`).
///
/// 4 tab là route con của `/home`, nên `context.go(Routes.courses)` cho stack
/// [Home, Courses]: Back luôn về Home, đổi tab không chồng route.
/// Màn chi tiết là route cấp cao, mở bằng `context.push(...)`.
class Routes {
  Routes._();

  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';

  static const home = '/home';
  static const courses = '/home/courses';
  static const schedule = '/home/schedule';
  static const account = '/home/account';

  static const myClassesPath = '/my-classes';
  static const classDetailPath = '/classes/:classId';
  static const paymentPath = '/payment/:orderId';

  /// origin: home | courses | account
  static String myClasses(String origin) => '$myClassesPath?origin=$origin';
  static String classDetail(String classId, {String? sessionId}) =>
      '/classes/$classId${sessionId == null ? '' : '?sessionId=$sessionId'}';
  static String payment(String orderId, {bool fromLearning = false}) =>
      '/payment/$orderId${fromLearning ? '?origin=learning' : ''}';

  // ---- Bài tập lập trình (Phase 7) - Học viên
  static const classCodePath = '/classes/:classId/code';
  static const codeAssignmentPath = '/code/:assignmentId';
  static const codeEditorPath = '/code/:assignmentId/editor';
  static String classCode(String classId) => '/classes/$classId/code';
  static String codeAssignment(String id) => '/code/$id';
  static String codeEditor(String id) => '/code/$id/editor';

  static const guestPages = {welcome, login, register};

  // ---- Staff: Manager và Mentor dùng Home + trang con mở bằng push.
  static const manager = '/manager';
  static const managerUtilities = '/manager/utilities';
  static const managerLeaves = '/manager/leave-requests';
  static const managerLeavePath = '/manager/leave-requests/:requestId';
  static String managerLeave(String id) => '$managerLeaves/$id';
  static const managerMaterials = '/manager/materials';
  static const managerMaterialNew = '/manager/materials/new';
  static const managerMaterialPath = '/manager/materials/:materialId';
  static const managerMaterialEditPath = '/manager/materials/:materialId/edit';
  static String managerMaterial(String id) => '$managerMaterials/$id';
  static String managerMaterialEdit(String id) => '${managerMaterial(id)}/edit';
  static const managerCollections = '/manager/collections';
  static const managerOrderPath = '/manager/orders/:orderId';
  static String managerOrder(String id) => '/manager/orders/$id';
  static const managerPeoplePath = '/manager/people/:role';
  static String managerPeople(String role) => '/manager/people/$role';
  static const managerPersonPath = '/manager/people/:role/:personId';
  static String managerPerson(String role, String id) =>
      '${managerPeople(role)}/$id';
  static const managerClasses = '/manager/classes';
  static const managerClassPath = '/manager/classes/:classId';
  static String managerClass(String id) => '$managerClasses/$id';
  static const managerIncomplete = '/manager/incomplete';
  static const managerAuditPath = '/manager/sessions/:sessionId/audits';
  static String managerAudit(String id) => '/manager/sessions/$id/audits';
  static const managerCorrectionPath = '/manager/correction/:sessionId';
  static const managerAttendanceAuditsPath = '/manager/audits/:sessionId';
  static const managerReports = '/manager/reports';
  static const managerMakeup = '/manager/makeup';
  static const managerMakeupPath = '/manager/makeup/:conflictId';
  static String managerMakeupDetail(String id) => '$managerMakeup/$id';

  static const mentor = '/mentor';
  // App staff clone RN (lib/features/staff): Hồ sơ / Cài đặt / Ngữ cảnh buổi theo role.
  static const mentorProfile = '/mentor/profile';
  static const mentorSettings = '/mentor/settings';
  static const managerProfile = '/manager/profile';
  static const managerSettings = '/manager/settings';
  static const mentorSessionPath = '/mentor/session/:sessionId';
  static String mentorSession(String id, {String? classTitle}) =>
      _withQuery('/mentor/session/$id', {'title': classTitle});
  static const managerSessionPath = '/manager/session/:sessionId';
  static String managerSession(String id, {String? tab, String? classTitle}) =>
      _withQuery('/manager/session/$id', {'tab': tab, 'title': classTitle});
  static String _withQuery(String path, Map<String, String?> query) {
    final q = {
      for (final e in query.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();
  }

  static const mentorAttendancePath = '/mentor/session/:sessionId/attendance';
  static String mentorAttendance(String id) => '/mentor/session/$id/attendance';
  static const mentorUtilities = '/mentor/utilities';
  static const mentorLeaveCreate = '/mentor/leave/new';
  static const mentorLeaveDetailPath = '/mentor/leave/:requestId';
  static String mentorLeaveDetail(String id) => '/mentor/leave/$id';
  static const mentorNotesPath = '/mentor/sessions/:sessionId/notes';
  static const mentorMeetingPath = '/mentor/sessions/:sessionId/meeting';
  static String mentorNotes(String id) => '/mentor/sessions/$id/notes';
  static const mentorSessionCodePath = '/mentor/sessions/:sessionId/code';
  static String mentorSessionCode(String id) => '/mentor/sessions/$id/code';
  static String mentorMeeting(String id) => '/mentor/sessions/$id/meeting';
  static const mentorPagePath = '/mentor/page/:key';
  static const mentorClassDetailPath = '/mentor/classes/:classId';
  static const mentorMaterialsPath = '/mentor/materials/:classId';
  static const mentorUploadPath = '/mentor/upload/:classId';
  static String mentorMaterials(String id) => '/mentor/materials/$id';
  static String mentorUpload(String id) => '/mentor/upload/$id';
  static String mentorClassDetail(String id) => '/mentor/classes/$id';
  static String mentorStudents(String id) =>
      '${mentorPage('students')}?classId=${Uri.encodeQueryComponent(id)}';
  static String mentorPage(String key) => '/mentor/page/$key';
}

/// Chọn trang đích theo phiên + vị trí hiện tại. Hàm thuần để test (test/widget_test.dart).
/// null = ở lại.
String? redirectFor(SessionState s, String loc) {
  if (!s.ready) return loc == Routes.splash ? null : Routes.splash;

  final user = s.user;
  if (user == null) {
    return Routes.guestPages.contains(loc) ? null : Routes.login;
  }

  final isManagerArea =
      loc == Routes.manager || loc.startsWith('${Routes.manager}/');
  final isMentorArea =
      loc == Routes.mentor || loc.startsWith('${Routes.mentor}/');
  switch (user.role) {
    case Role.STUDENT:
      if (loc == Routes.splash ||
          Routes.guestPages.contains(loc) ||
          isMentorArea ||
          isManagerArea) {
        return Routes.home;
      }
      return null;
    case Role.MENTOR:
      return isMentorArea ? null : Routes.mentor;
    case Role.MANAGER:
      return isManagerArea ? null : Routes.manager;
    case Role.ADMIN:
      // ADMIN chưa có không gian mobile: màn tài khoản nhân sự + Đăng xuất
      return loc == Routes.welcome ? null : Routes.welcome;
  }
}

/// Tab dưới đáy. `notifications` chưa có API nên luôn disabled.
enum HomeTab { courses, schedule, home, notifications, account }

/// Đổi tab - thay `navigateLearningTab` bên RN.
void goTab(BuildContext context, HomeTab tab) {
  switch (tab) {
    case HomeTab.home:
      context.go(Routes.home);
    case HomeTab.courses:
      context.go(Routes.courses);
    case HomeTab.schedule:
      context.go(Routes.schedule);
    case HomeTab.account:
      context.go(Routes.account);
    case HomeTab.notifications:
      break;
  }
}
