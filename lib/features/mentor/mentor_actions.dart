import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/session/session_controller.dart';
import '../../core/ui/states.dart';
import '../../core/ui/staff/staff_widgets.dart';
import 'mentor_utilities.dart';
import 'attendance/attendance_sheet.dart';
import 'schedule/schedule_models.dart';
import 'schedule/schedule_providers.dart';
import 'session/live_room_sheet.dart';

Future<void> openMentorSessionUtility(BuildContext context, WidgetRef ref, MentorUtil utility) async {
  final t = ref.read(trProvider);
  final epoch = ref.read(sessionEpochProvider);
  final clock = ref.read(mentorClockProvider);
  try {
    final schedule = await ref.read(mentorScheduleProvider(mentorHomeQuery).future);
    if (!context.mounted || ref.read(sessionEpochProvider) != epoch) return;
    // nextToday có thể trả buổi sắp tới: chỉ nhận buổi đang diễn ra cho tiện ích buổi.
    final entry = schedule.nextToday(clock());
    if (entry == null || entry.session.displayStatus(clock()) != TeachingDisplayStatus.live) {
      showStaffToast(context, t('mentor.session.noLive'));
      return;
    }
    if (utility == MentorUtil.room) {
      showMentorRoom(context, ref, entry);
    } else {
      await showMentorAttendance(context, ref, entry, openSync: true);
    }
  } catch (error) {
    if (!context.mounted) return;
    showStaffToast(context, t(errorKey(error)));
  }
}
