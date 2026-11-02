import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/routes.dart';
import '../core/session/session_controller.dart';
import '../features/account/account_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/courses/courses_screen.dart';
import '../features/home/home_screen.dart';
import '../features/manager/manager_home_screen.dart';
import '../features/manager/leave/leave_screens.dart';
import '../features/manager/materials/materials_api.dart' show MaterialReviewStatus;
import '../features/manager/materials/materials_screens.dart';
import '../features/manager/materials/material_editor.dart';
import '../features/manager/collections/collections_screens.dart';
import '../features/manager/operations/read_screens.dart';
import '../features/manager/operations/makeup_screens.dart';
import '../features/mentor/live_mentor_home_screen.dart';
import '../features/mentor/classes/classes_screen.dart';
import '../features/mentor/classes/class_detail_screen.dart';
import '../features/mentor/reports/attendance_report_screen.dart';
import '../features/mentor/students/students_screen.dart';
import '../features/mentor/materials/materials_screen.dart';
import '../features/mentor/materials/upload_screen.dart';
import '../features/mentor/mentor_pages.dart';
import '../core/ui/session_sheet_guard.dart';
import '../features/mentor/operations/leave_screens.dart';
import '../features/mentor/operations/session_edit_screens.dart';
import '../features/mentor/schedule/live_schedule_screen.dart';
import '../features/mentor/substitute/live_substitute_screen.dart';
import '../features/my_classes/class_detail_screen.dart';
import '../features/my_classes/my_classes_screen.dart';
import '../features/payment/payment_screen.dart';
import '../features/schedule/schedule_screen.dart';

/// Bảng route - tương đương `navigation/index.tsx`.
///
/// Guard theo role nằm ở `redirectFor` (core/router/routes.dart):
/// splash -> guest (login/register/welcome) -> STUDENT: /home... · MENTOR: /mentor... · khác: /welcome
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(ref.read(sessionProvider), state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: Routes.home,
        builder: (_, _) => const HomeScreen(),
        routes: [
          GoRoute(path: 'courses', builder: (_, _) => const CoursesScreen()),
          GoRoute(path: 'schedule', builder: (_, _) => const ScheduleScreen()),
          GoRoute(path: 'account', builder: (_, _) => const AccountScreen()),
        ],
      ),
      GoRoute(
        path: Routes.myClassesPath,
        builder: (_, st) => MyClassesScreen(origin: st.uri.queryParameters['origin'] ?? 'account'),
      ),
      GoRoute(
        path: Routes.classDetailPath,
        builder: (_, st) =>
            ClassDetailScreen(classId: st.pathParameters['classId']!, sessionId: st.uri.queryParameters['sessionId']),
      ),
      GoRoute(
        path: Routes.mentorLeaveCreate,
        builder: (_, _) => const SessionBoundView(child: MentorLeaveCreateScreen()),
      ),
      GoRoute(
        path: Routes.mentorLeaveDetailPath,
        builder: (_, state) =>
            SessionBoundView(child: MentorLeaveDetailScreen(requestId: state.pathParameters['requestId']!)),
      ),
      GoRoute(
        path: Routes.mentorNotesPath,
        builder: (_, state) =>
            SessionBoundView(child: MentorNotesScreen(sessionId: state.pathParameters['sessionId']!)),
      ),
      GoRoute(
        path: Routes.mentorMeetingPath,
        builder: (_, state) =>
            SessionBoundView(child: MentorMeetingScreen(sessionId: state.pathParameters['sessionId']!)),
      ),
      // Manager: mọi form riêng tư tạo State mới khi đổi actor.
      GoRoute(
        path: Routes.manager,
        builder: (_, _) => const SessionBoundView(child: ManagerHomeScreen()),
      ),
      GoRoute(
        path: Routes.managerUtilities,
        builder: (_, _) => const SessionBoundView(child: ManagerUtilitiesScreen()),
      ),
      GoRoute(
        path: Routes.managerLeaves,
        builder: (_, _) => const SessionBoundView(child: ManagerLeavesScreen()),
      ),
      GoRoute(
        path: Routes.managerLeavePath,
        builder: (_, s) => SessionBoundView(child: ManagerLeaveDetailScreen(id: s.pathParameters['requestId']!)),
      ),
      GoRoute(
        path: Routes.managerMaterialNew,
        builder: (_, s) => SessionBoundView(child: ManagerMaterialEditor(unitId: s.uri.queryParameters['unitId'])),
      ),
      GoRoute(
        path: Routes.managerMaterialEditPath,
        builder: (_, s) => SessionBoundView(child: ManagerMaterialEditor(id: s.pathParameters['materialId']!)),
      ),
      GoRoute(
        path: Routes.managerMaterialPath,
        builder: (_, s) => SessionBoundView(child: ManagerMaterialScreen(id: s.pathParameters['materialId']!)),
      ),
      GoRoute(
        path: Routes.managerMaterials,
        builder: (_, s) => SessionBoundView(
          child: ManagerMaterialsScreen(
            unitId: s.uri.queryParameters['unitId'],
            initialStatus: MaterialReviewStatus.values
                .where((v) => v.name == s.uri.queryParameters['status'])
                .firstOrNull,
          ),
        ),
      ),
      GoRoute(
        path: Routes.managerCollections,
        builder: (_, _) => const SessionBoundView(child: ManagerCollectionsScreen()),
      ),
      GoRoute(
        path: Routes.managerOrderPath,
        builder: (_, s) => SessionBoundView(child: ManagerOrderScreen(id: s.pathParameters['orderId']!)),
      ),
      GoRoute(
        path: Routes.managerPeoplePath,
        builder: (_, s) => SessionBoundView(child: ManagerPeopleScreen(role: s.pathParameters['role']!)),
      ),
      GoRoute(
        path: Routes.managerPersonPath,
        builder: (_, s) => SessionBoundView(
          child: ManagerPersonScreen(role: s.pathParameters['role']!, id: s.pathParameters['personId']!),
        ),
      ),
      GoRoute(
        path: Routes.managerClasses,
        builder: (_, _) => const SessionBoundView(child: ManagerClassesScreen()),
      ),
      GoRoute(
        path: Routes.managerClassPath,
        builder: (_, s) => SessionBoundView(child: ManagerClassScreen(id: s.pathParameters['classId']!)),
      ),
      GoRoute(
        path: Routes.managerIncomplete,
        builder: (_, _) => const SessionBoundView(child: ManagerIncompleteScreen()),
      ),
      GoRoute(
        path: Routes.managerReports,
        builder: (_, s) => SessionBoundView(child: ManagerReportScreen(classId: s.uri.queryParameters['classId'])),
      ),
      GoRoute(
        path: Routes.managerAuditPath,
        builder: (_, s) => SessionBoundView(child: ManagerAuditScreen(sessionId: s.pathParameters['sessionId']!)),
      ),
      GoRoute(
        path: Routes.managerMakeup,
        builder: (_, _) => const SessionBoundView(child: ManagerMakeupScreen()),
      ),
      GoRoute(
        path: Routes.managerMakeupPath,
        builder: (_, s) => SessionBoundView(child: ManagerMakeupDetailScreen(id: s.pathParameters['conflictId']!)),
      ),
      // ---- Mentor
      GoRoute(path: Routes.mentor, builder: (_, _) => const LiveMentorHomeScreen()),
      GoRoute(path: Routes.mentorUtilities, builder: (_, _) => const MentorUtilitiesScreen()),
      GoRoute(
        path: Routes.mentorMaterialsPath,
        builder: (_, st) => MentorMaterialsScreen(classId: st.pathParameters['classId']!),
      ),
      GoRoute(
        path: Routes.mentorUploadPath,
        builder: (_, st) => MentorUploadScreen(classId: st.pathParameters['classId']!),
      ),
      GoRoute(
        path: Routes.mentorClassDetailPath,
        builder: (_, st) => MentorClassDetailScreen(classId: st.pathParameters['classId']!),
      ),
      GoRoute(
        path: Routes.mentorPagePath,
        builder: (_, st) => switch (st.pathParameters['key']) {
          'schedule' => const LiveMentorScheduleScreen(),
          'leave' => const SessionBoundView(child: MentorLeaveScreen()),
          'substitute' => const LiveMentorSubstituteScreen(),
          'classes' => const MentorClassesScreen(),
          'attendance' => const MentorAttendanceReportScreen(),
          'students' => MentorStudentsScreen(classId: st.uri.queryParameters['classId']),
          'materials' => const MentorMaterialsScreen(),
          'upload' => const MentorUploadScreen(),
          _ => const MentorUnavailablePage(),
        },
      ),
      GoRoute(
        path: Routes.paymentPath,
        builder: (_, st) => SessionBoundView(
          child: PaymentScreen(
            orderId: st.pathParameters['orderId']!,
            fromLearning: st.uri.queryParameters['origin'] == 'learning',
          ),
        ),
      ),
    ],
  );
});
