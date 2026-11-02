import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/utils/format.dart';
import '../classes/classes_providers.dart';
import '../session/live_room_sheet.dart';
import 'schedule_providers.dart';
import 'schedule_screen.dart';

class LiveMentorScheduleScreen extends ConsumerStatefulWidget {
  const LiveMentorScheduleScreen({super.key});
  @override
  ConsumerState<LiveMentorScheduleScreen> createState() => _LiveMentorScheduleScreenState();
}

class _LiveMentorScheduleScreenState extends ConsumerState<LiveMentorScheduleScreen> {
  String? _day;
  late final Timer _ticker;
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final zone = ref.watch(mentorTimeZoneProvider);
    return zone.when(
      loading: () => StaffPage(
        title: t('mentor.schedule.title'),
        body: const Padding(padding: EdgeInsets.all(24), child: Skeleton(height: 200)),
      ),
      error: (error, _) => StaffPage(
        title: t('mentor.schedule.title'),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: StaffDataState(
            title: t('mentor.schedule.loadError'),
            description: t(errorKey(error)),
            error: error,
            onRetry: () => ref.invalidate(mentorTimeZoneProvider),
          ),
        ),
      ),
      data: (zone) {
        final now = ref.watch(mentorClockProvider)();
        final day = _day ?? Dates.localDay(now, zone);
        final query = (window: MentorScheduleWindow.week, day: day);
        void refresh() {
          ref.invalidate(mentorClassesProvider);
          ref.invalidate(mentorScheduleProvider(query));
        }

        return MentorScheduleScreen(
          value: ref.watch(mentorScheduleProvider(query)),
          selectedDay: day,
          now: now,
          onDaySelected: (value) => setState(() => _day = value),
          onWeekChanged: (weeks) => setState(() => _day = Dates.shiftDay(day, weeks * 7)),
          onRefresh: () async => refresh(),
          onRetry: refresh,
          onRoom: (entry) => showMentorRoom(context, ref, entry),
          onAttendance: (_) => showStaffToast(context, t('mentor.preview.attendance')),
        );
      },
    );
  }
}
