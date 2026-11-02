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
import '../features/mentor/live_mentor_home_screen.dart';
import '../features/mentor/classes/classes_screen.dart';
import '../features/mentor/classes/class_detail_screen.dart';
import '../features/mentor/reports/attendance_report_screen.dart';
import '../features/mentor/students/students_screen.dart';
import '../features/mentor/materials/materials_screen.dart';
import '../features/mentor/materials/upload_screen.dart';
import '../features/mentor/mentor_pages.dart';
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
          'substitute' => const LiveMentorSubstituteScreen(),
          'classes' => const MentorClassesScreen(),
          'attendance' => const MentorAttendanceReportScreen(),
          'students' => MentorStudentsScreen(classId: st.uri.queryParameters['classId']),
          'materials' => const MentorMaterialsScreen(),
          'upload' => const MentorUploadScreen(),
          _ => MentorPlaceholderPage(utilKey: st.pathParameters['key']!),
        },
      ),
      GoRoute(
        path: Routes.paymentPath,
        builder: (_, st) => PaymentScreen(
          orderId: st.pathParameters['orderId']!,
          fromLearning: st.uri.queryParameters['origin'] == 'learning',
        ),
      ),
    ],
  );
});
