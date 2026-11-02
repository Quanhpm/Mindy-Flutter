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
import '../features/code_assignments/code_assignments_screen.dart';
import '../features/code_assignments/code_editor_screen.dart';
import '../features/code_assignments/code_problem_screen.dart';
import '../features/courses/courses_screen.dart';
import '../features/home/home_screen.dart';
import '../features/manager/manager_home_screen.dart';
import '../features/manager/materials/material_editor.dart';
import '../features/manager/collections/collections_screens.dart';
import '../features/manager/operations/read_screens.dart';
import '../features/mentor/code/mentor_session_code_screen.dart';
import '../features/mentor/students/students_screen.dart';
import '../features/mentor/materials/upload_screen.dart';
import '../features/mentor/mentor_pages.dart';
import '../core/ui/session_sheet_guard.dart';
import '../features/mentor/operations/session_edit_screens.dart';
import '../features/mentor/substitute/live_substitute_screen.dart';
import '../features/my_classes/class_detail_screen.dart';
import '../features/my_classes/my_classes_screen.dart';
import '../features/payment/payment_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/staff/attendance/attendance_editor_screen.dart';
import '../features/staff/attendance/audits_screen.dart';
import '../features/staff/attendance/incomplete_screen.dart';
import '../features/staff/attendance/manager_attendance_screens.dart';
import '../features/staff/attendance/note_editor_screen.dart';
import '../features/staff/auth/profile_settings_screens.dart';
import '../features/staff/auth/workspace_screen.dart';
import '../features/staff/leave/leave_detail_screen.dart';
import '../features/staff/leave/leave_list_screens.dart';
import '../features/staff/leave/leave_plan_screen.dart';
import '../features/staff/leave/makeup_placement_screen.dart';
import '../features/staff/materials/materials_screens.dart';
import '../features/staff/materials/material_detail_screen.dart';
import '../features/staff/materials/material_editor_screen.dart';
import '../features/staff/materials/material_preview_screen.dart';
import '../features/staff/quiz/quiz_list_screen.dart';
import '../features/staff/quiz/quiz_editor_screen.dart';
import '../features/staff/quiz/quiz_detail_screen.dart';
import '../features/staff/reports/reports_screens.dart';
import '../features/staff/chat/chat_screens.dart';
import '../features/staff/operations/cash_screens.dart';
import '../features/staff/operations/session_form_screen.dart';
import '../features/staff/operations/session_operations.dart';
import '../features/staff/shared/remote.dart';
import '../features/staff/shared/unavailable_screen.dart';
import '../features/staff/teaching/class_detail_screens.dart';
import '../features/staff/teaching/classes_screens.dart';
import '../features/staff/teaching/manager_class_detail_screen.dart';
import '../features/staff/teaching/schedule_screen.dart';
import '../features/staff/teaching/session_context_screen.dart';

/// Kiểm tra ID trước khi dựng màn và reset nháp khi đổi resource/query.
Widget _staffResource(
  GoRouterState state,
  String parameter, {
  required Widget Function() builder,
  bool manager = false,
}) => SessionBoundView(
  child: isUuid(state.pathParameters[parameter])
      ? KeyedSubtree(key: ValueKey(state.uri.toString()), child: builder())
      : StaffUnavailableScreen(manager: manager),
);

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
    redirect: (context, state) =>
        redirectFor(ref.read(sessionProvider), state.matchedLocation),
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
        builder: (_, st) => MyClassesScreen(
          origin: st.uri.queryParameters['origin'] ?? 'account',
        ),
      ),
      GoRoute(
        path: Routes.classDetailPath,
        builder: (_, st) => ClassDetailScreen(
          classId: st.pathParameters['classId']!,
          sessionId: st.uri.queryParameters['sessionId'],
        ),
      ),
      GoRoute(
        path: Routes.classCodePath,
        builder: (_, st) => SessionBoundView(
          child: CodeAssignmentsScreen(classId: st.pathParameters['classId']!),
        ),
      ),
      GoRoute(
        path: Routes.codeAssignmentPath,
        builder: (_, st) => SessionBoundView(
          child: CodeProblemScreen(
            assignmentId: st.pathParameters['assignmentId']!,
          ),
        ),
      ),
      GoRoute(
        path: Routes.codeEditorPath,
        builder: (_, st) => SessionBoundView(
          child: CodeEditorScreen(
            assignmentId: st.pathParameters['assignmentId']!,
          ),
        ),
      ),
      GoRoute(
        path: Routes.mentorSessionCodePath,
        builder: (_, st) => SessionBoundView(
          child: MentorSessionCodeScreen(
            sessionId: st.pathParameters['sessionId']!,
          ),
        ),
      ),
      GoRoute(
        path: Routes.mentorLeaveCreate,
        builder: (_, _) =>
            const SessionBoundView(child: StaffLeavePlanScreen()),
      ),
      GoRoute(
        path: Routes.mentorLeaveDetailPath,
        builder: (_, state) => SessionBoundView(
          child: isUuid(state.pathParameters['requestId'])
              ? StaffLeaveDetailScreen(
                  key: ValueKey(state.uri.toString()),
                  id: state.pathParameters['requestId']!,
                  manager: false,
                )
              : const StaffUnavailableScreen(manager: false),
        ),
      ),
      GoRoute(
        path: Routes.mentorNotesPath,
        builder: (_, state) => _staffResource(
          state,
          'sessionId',
          manager: false,
          builder: () => StaffTeachingNoteEditorScreen(
            sessionId: state.pathParameters['sessionId']!,
            classTitle: state.uri.queryParameters['title'],
          ),
        ),
      ),
      GoRoute(
        path: Routes.mentorMeetingPath,
        builder: (_, state) => SessionBoundView(
          child: MentorMeetingScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
      ),
      // Manager: mọi form riêng tư tạo State mới khi đổi actor.
      GoRoute(
        path: Routes.manager,
        builder: (_, _) =>
            const SessionBoundView(child: StaffWorkspaceScreen()),
      ),
      GoRoute(
        path: Routes.managerProfile,
        builder: (_, _) => const StaffProfileScreen(),
      ),
      GoRoute(
        path: Routes.managerSettings,
        builder: (_, _) => const StaffSettingsScreen(),
      ),
      GoRoute(
        path: Routes.managerUtilities,
        builder: (_, _) =>
            const SessionBoundView(child: ManagerUtilitiesScreen()),
      ),
      GoRoute(
        path: Routes.managerLeaves,
        builder: (_, _) =>
            const SessionBoundView(child: StaffLeaveListScreen(manager: true)),
      ),
      GoRoute(
        path: Routes.managerLeavePath,
        builder: (_, s) => SessionBoundView(
          child: isUuid(s.pathParameters['requestId'])
              ? StaffLeaveDetailScreen(
                  key: ValueKey(s.uri.toString()),
                  id: s.pathParameters['requestId']!,
                  manager: true,
                )
              : const StaffUnavailableScreen(manager: true),
        ),
      ),
      GoRoute(
        path: Routes.managerMaterialNew,
        builder: (_, s) => SessionBoundView(
          child: ManagerMaterialEditor(unitId: s.uri.queryParameters['unitId']),
        ),
      ),
      GoRoute(
        path: Routes.managerMaterialEditPath,
        builder: (_, s) => SessionBoundView(
          child: ManagerMaterialEditor(id: s.pathParameters['materialId']!),
        ),
      ),
      GoRoute(
        path: Routes.managerMaterialPath,
        builder: (_, s) => SessionBoundView(
          child: StaffMaterialDetailScreen(
            id: s.pathParameters['materialId']!,
            manager: true,
          ),
        ),
      ),
      GoRoute(
        path: Routes.managerMaterials,
        builder: (_, _) =>
            const SessionBoundView(child: StaffMaterialsScreen(manager: true)),
      ),
      GoRoute(
        path: Routes.managerCollections,
        builder: (_, _) =>
            const SessionBoundView(child: ManagerCollectionsScreen()),
      ),
      GoRoute(
        path: Routes.managerOrderPath,
        builder: (_, s) => SessionBoundView(
          child: ManagerOrderScreen(id: s.pathParameters['orderId']!),
        ),
      ),
      GoRoute(
        path: Routes.managerPeoplePath,
        builder: (_, s) => SessionBoundView(
          child: ManagerPeopleScreen(role: s.pathParameters['role']!),
        ),
      ),
      GoRoute(
        path: Routes.managerPersonPath,
        builder: (_, s) => SessionBoundView(
          child: ManagerPersonScreen(
            role: s.pathParameters['role']!,
            id: s.pathParameters['personId']!,
          ),
        ),
      ),
      GoRoute(
        path: Routes.managerClasses,
        builder: (_, _) =>
            const SessionBoundView(child: StaffClassesScreen(manager: true)),
      ),
      GoRoute(
        path: Routes.managerClassPath,
        builder: (_, s) => SessionBoundView(
          child: StaffManagerClassDetailScreen(
            classId: s.pathParameters['classId']!,
          ),
        ),
      ),
      GoRoute(
        path: Routes.managerIncomplete,
        builder: (_, _) =>
            const SessionBoundView(child: StaffIncompleteSessionsScreen()),
      ),
      GoRoute(
        path: Routes.managerReports,
        builder: (_, s) => SessionBoundView(
          child: ManagerReportScreen(classId: s.uri.queryParameters['classId']),
        ),
      ),
      GoRoute(
        path: Routes.managerAuditPath,
        builder: (_, s) => _staffResource(
          s,
          'sessionId',
          manager: true,
          builder: () => StaffAttendanceAuditsScreen(
            params: correctionParamsOf(
              s.pathParameters['sessionId']!,
              s.uri.queryParameters,
            ),
          ),
        ),
      ),
      GoRoute(
        path: Routes.managerMakeup,
        builder: (_, _) =>
            const SessionBoundView(child: StaffMakeupConflictsScreen()),
      ),
      GoRoute(
        path: Routes.managerMakeupPath,
        builder: (_, s) => SessionBoundView(
          child:
              isUuid(s.pathParameters['conflictId']) &&
                  isUuid(s.uri.queryParameters['classId'])
              ? StaffMakeupPlacementScreen(
                  key: ValueKey(s.uri.toString()),
                  conflictId: s.pathParameters['conflictId']!,
                  classId: s.uri.queryParameters['classId']!,
                )
              : const StaffUnavailableScreen(manager: true),
        ),
      ),
      // ---- Manager: điểm danh (clone RN)
      GoRoute(
        path: Routes.managerCorrectionPath,
        builder: (_, s) => _staffResource(
          s,
          'sessionId',
          manager: true,
          builder: () => StaffAttendanceEditorScreen(
            key: ValueKey(s.uri.toString()),
            params: correctionParamsOf(
              s.pathParameters['sessionId']!,
              s.uri.queryParameters,
            ),
            manager: true,
          ),
        ),
      ),
      GoRoute(
        path: Routes.managerAttendanceAuditsPath,
        builder: (_, s) => _staffResource(
          s,
          'sessionId',
          manager: true,
          builder: () => StaffAttendanceAuditsScreen(
            key: ValueKey(s.uri.toString()),
            params: correctionParamsOf(
              s.pathParameters['sessionId']!,
              s.uri.queryParameters,
            ),
          ),
        ),
      ),
      GoRoute(
        path: StaffAttendanceRoutes.management,
        builder: (_, _) =>
            const SessionBoundView(child: StaffAttendanceManagementScreen()),
      ),
      GoRoute(
        path: StaffAttendanceRoutes.studentPath,
        builder: (_, s) => _staffResource(
          s,
          'studentId',
          manager: true,
          builder: () => StaffStudentAttendanceFormScreen(
            studentId: s.pathParameters['studentId']!,
            studentName: s.uri.queryParameters['name'],
          ),
        ),
      ),
      GoRoute(
        path: StaffAttendanceRoutes.finalizeSessions,
        builder: (_, _) =>
            const SessionBoundView(child: StaffFinalizeSessionsScreen()),
      ),
      GoRoute(
        path: StaffAttendanceRoutes.finalizePath,
        builder: (_, s) => _staffResource(
          s,
          'sessionId',
          manager: true,
          builder: () => StaffManagerFinalizeScreen(
            sessionId: s.pathParameters['sessionId']!,
            classTitle: s.uri.queryParameters['title'],
          ),
        ),
      ),
      // ---- Manager: điều phối buổi + tiền mặt (clone RN)
      for (final (path, mode) in [
        (StaffOpsRoutes.assignPath, SessionFormMode.assign),
        (StaffOpsRoutes.reschedulePath, SessionFormMode.reschedule),
        (StaffOpsRoutes.replacePath, SessionFormMode.replacement),
      ])
        GoRoute(
          path: path,
          builder: (_, s) => _staffResource(
            s,
            'sessionId',
            manager: true,
            builder: () => StaffSessionFormScreen(
              sessionId: s.pathParameters['sessionId']!,
              mode: mode,
              classTitle: s.uri.queryParameters['title'],
            ),
          ),
        ),
      GoRoute(
        path: StaffOpsRoutes.cashOrders,
        builder: (_, _) =>
            const SessionBoundView(child: StaffCashOrdersScreen()),
      ),
      GoRoute(
        path: StaffOpsRoutes.cashOrderPath,
        builder: (_, s) => _staffResource(
          s,
          'orderId',
          manager: true,
          builder: () => StaffCashOrderDetailScreen(
            orderId: s.pathParameters['orderId']!,
            orderCode: s.uri.queryParameters['code'],
          ),
        ),
      ),
      // ---- Mentor
      GoRoute(
        path: Routes.mentor,
        builder: (_, _) =>
            const SessionBoundView(child: StaffWorkspaceScreen()),
      ),
      GoRoute(
        path: Routes.mentorProfile,
        builder: (_, _) => const StaffProfileScreen(),
      ),
      GoRoute(
        path: Routes.mentorSettings,
        builder: (_, _) => const StaffSettingsScreen(),
      ),
      GoRoute(
        path: Routes.mentorSessionPath,
        builder: (_, s) => StaffSessionContextScreen(
          sessionId: s.pathParameters['sessionId']!,
          manager: false,
          classTitle: s.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: Routes.managerSessionPath,
        builder: (_, s) => StaffSessionContextScreen(
          key: ValueKey(s.uri.toString()),
          sessionId: s.pathParameters['sessionId']!,
          manager: true,
          classTitle: s.uri.queryParameters['title'],
          initialTab: s.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: Routes.mentorAttendancePath,
        builder: (_, s) => _staffResource(
          s,
          'sessionId',
          manager: false,
          builder: () => StaffAttendanceEditorScreen(
            params: correctionParamsOf(
              s.pathParameters['sessionId']!,
              s.uri.queryParameters,
            ),
            manager: false,
          ),
        ),
      ),
      GoRoute(
        path: Routes.mentorUtilities,
        builder: (_, _) => const MentorUtilitiesScreen(),
      ),
      GoRoute(
        path: StaffChatRoutes.conversations,
        builder: (_, _) =>
            const SessionBoundView(child: StaffChatConversationsScreen()),
      ),
      GoRoute(
        path: StaffChatRoutes.notifications,
        builder: (_, _) =>
            const SessionBoundView(child: StaffChatNotificationsScreen()),
      ),
      GoRoute(
        path: StaffChatRoutes.roomPath,
        builder: (_, s) => _staffResource(
          s,
          'conversationId',
          builder: () => StaffChatRoomScreen(
            id: s.pathParameters['conversationId']!,
            title: s.uri.queryParameters['title'],
          ),
        ),
      ),
      GoRoute(
        path: StaffReportRoutes.mentorPath,
        builder: (_, s) => _staffResource(
          s,
          'classId',
          builder: () => StaffReportScreen(
            classId: s.pathParameters['classId']!,
            classTitle: s.uri.queryParameters['title'],
          ),
        ),
      ),
      GoRoute(
        path: StaffReportRoutes.managerPath,
        builder: (_, s) => _staffResource(
          s,
          'classId',
          manager: true,
          builder: () => StaffReportScreen(
            classId: s.pathParameters['classId']!,
            classTitle: s.uri.queryParameters['title'],
            manager: true,
          ),
        ),
      ),
      GoRoute(
        path: StaffReportRoutes.studentPath,
        builder: (_, s) => _staffResource(
          s,
          'studentId',
          builder: () => StaffReportScreen(
            classId: s.pathParameters['classId']!,
            studentId: s.pathParameters['studentId']!,
            studentName: s.uri.queryParameters['name'],
            classTitle: s.uri.queryParameters['title'],
            initialTab: s.uri.queryParameters['tab'],
            range:
                s.uri.queryParameters['from'] != null &&
                    s.uri.queryParameters['to'] != null
                ? (
                    from: s.uri.queryParameters['from']!,
                    to: s.uri.queryParameters['to']!,
                  )
                : null,
          ),
        ),
      ),
      GoRoute(
        path: StaffQuizRoutes.classPath,
        builder: (_, s) => _staffResource(
          s,
          'classId',
          builder: () => StaffQuizListScreen(
            classId: s.pathParameters['classId']!,
            classTitle: s.uri.queryParameters['title'],
            sessionId: s.uri.queryParameters['sessionId'],
            sessionTitle: s.uri.queryParameters['sessionTitle'],
          ),
        ),
      ),
      GoRoute(
        path: StaffQuizRoutes.editorPath,
        builder: (_, s) => _staffResource(
          s,
          'sessionId',
          builder: () => StaffQuizEditorScreen(
            classId: s.pathParameters['classId']!,
            sessionId: s.pathParameters['sessionId']!,
            id: s.uri.queryParameters['id'],
            title: s.uri.queryParameters['title'],
            initialTab: s.uri.queryParameters['tab'] ?? 'info',
          ),
        ),
      ),
      GoRoute(
        path: StaffQuizRoutes.detailPath,
        builder: (_, s) => _staffResource(
          s,
          'assignmentId',
          builder: () => StaffQuizDetailScreen(
            classId: s.pathParameters['classId']!,
            id: s.pathParameters['assignmentId']!,
          ),
        ),
      ),
      GoRoute(
        path: StaffMaterialRoutes.mentorDetailPath,
        builder: (_, s) => _staffResource(
          s,
          'materialId',
          builder: () => StaffMaterialDetailScreen(
            id: s.pathParameters['materialId']!,
            classId: s.pathParameters['classId']!,
          ),
        ),
      ),
      GoRoute(
        path: StaffMaterialRoutes.editorPath,
        builder: (_, s) => SessionBoundView(
          child:
              isUuid(s.pathParameters['classId']) &&
                  isUuid(s.uri.queryParameters['unitId']) &&
                  isUuid(s.uri.queryParameters['courseUnitId'])
              ? StaffMaterialEditorScreen(
                  key: ValueKey(s.uri.toString()),
                  classId: s.pathParameters['classId']!,
                  classUnitId: s.uri.queryParameters['unitId']!,
                  courseUnitId: s.uri.queryParameters['courseUnitId']!,
                  id: s.uri.queryParameters['materialId'],
                  unitTitle: s.uri.queryParameters['title'],
                )
              : const StaffUnavailableScreen(manager: false),
        ),
      ),
      for (final manager in [false, true])
        GoRoute(
          path:
              '/${manager ? 'manager' : 'mentor'}/material-preview/:materialId',
          builder: (_, s) => _staffResource(
            s,
            'materialId',
            manager: manager,
            builder: () => StaffMaterialPreviewScreen(
              id: s.pathParameters['materialId']!,
              revision:
                  int.tryParse(s.uri.queryParameters['revision'] ?? '') ?? 0,
              title: s.uri.queryParameters['title'] ?? '',
              classId: s.uri.queryParameters['classId'],
              fileId: s.uri.queryParameters['fileId'],
              manager: manager,
            ),
          ),
        ),
      GoRoute(
        path: Routes.mentorMaterialsPath,
        builder: (_, st) => StaffMaterialsScreen(
          key: ValueKey(st.uri.toString()),
          classId: st.pathParameters['classId']!,
          classTitle: st.uri.queryParameters['title'],
          unitId: st.uri.queryParameters['unitId'],
        ),
      ),
      GoRoute(
        path: Routes.mentorUploadPath,
        builder: (_, st) =>
            MentorUploadScreen(classId: st.pathParameters['classId']!),
      ),
      GoRoute(
        path: Routes.mentorClassDetailPath,
        builder: (_, st) => StaffMentorClassDetailScreen(
          classId: st.pathParameters['classId']!,
        ),
      ),
      GoRoute(
        path: Routes.mentorPagePath,
        builder: (_, st) => switch (st.pathParameters['key']) {
          'chat' => const SessionBoundView(
            child: StaffChatConversationsScreen(),
          ),
          'quiz' => const SessionBoundView(child: StaffQuizListScreen()),
          'schedule' => const StaffTeachingScheduleScreen(),
          'leave' => const SessionBoundView(
            child: StaffLeaveListScreen(manager: false),
          ),
          'substitute' => const LiveMentorSubstituteScreen(),
          'classes' => const StaffClassesScreen(manager: false),
          'attendance' => const SessionBoundView(
            child: StaffReportClassesScreen(),
          ),
          'students' =>
            isUuid(st.uri.queryParameters['classId'])
                ? StaffMentorStudentsScreen(
                    classId: st.uri.queryParameters['classId']!,
                  )
                : MentorStudentsScreen(
                    classId: st.uri.queryParameters['classId'],
                  ),
          'materials' => const SessionBoundView(child: StaffMaterialsScreen()),
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
