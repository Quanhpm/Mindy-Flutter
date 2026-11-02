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

  static const guestPages = {welcome, login, register};

  // ---- Mentor (MENTOR_PLAN.md). Không có tab bar: Home + trang con mở bằng push.
  static const mentor = '/mentor';
  static const mentorUtilities = '/mentor/utilities';
  static const mentorPagePath = '/mentor/page/:key';
  static String mentorPage(String key) => '/mentor/page/$key';
}

/// Chọn trang đích theo phiên + vị trí hiện tại. Hàm thuần để test (test/widget_test.dart).
/// null = ở lại.
String? redirectFor(SessionState s, String loc) {
  if (!s.ready) return loc == Routes.splash ? null : Routes.splash;

  final user = s.user;
  if (user == null) return Routes.guestPages.contains(loc) ? null : Routes.login;

  final isMentorArea = loc == Routes.mentor || loc.startsWith('${Routes.mentor}/');
  switch (user.role) {
    case Role.STUDENT:
      if (loc == Routes.splash || Routes.guestPages.contains(loc) || isMentorArea) return Routes.home;
      return null;
    case Role.MENTOR:
      return isMentorArea ? null : Routes.mentor;
    case Role.MANAGER:
    case Role.ADMIN:
      // Chưa có app Quản lý: màn "tài khoản nhân sự" + Đăng xuất
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
