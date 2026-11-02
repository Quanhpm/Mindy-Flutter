import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../classes/classes_providers.dart';
import '../attendance/attendance_sheet.dart';
import '../schedule/schedule_providers.dart';
import '../session/live_room_sheet.dart';
import '../operations/session_edit_screens.dart';
import 'substitute_screen.dart';

class LiveMentorSubstituteScreen extends ConsumerWidget {
  const LiveMentorSubstituteScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void refresh() {
      ref.invalidate(mentorClassesProvider);
      ref.invalidate(mentorScheduleProvider(mentorSubstituteQuery));
    }

    return MentorSubstituteScreen(
      value: ref.watch(mentorScheduleProvider(mentorSubstituteQuery)),
      now: ref.watch(mentorNowProvider).value ?? ref.watch(mentorClockProvider)(),
      onRetry: refresh,
      onRefresh: () async => refresh(),
      onRoom: (entry) => showMentorRoom(context, ref, entry),
      onAttendance: (entry) => showMentorAttendance(context, ref, entry),
      onTools: (entry) => showMentorSessionTools(context, ref, entry),
    );
  }
}
