import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/day_strip.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';
import '../../../core/utils/format.dart';
import 'schedule_models.dart';
import 'schedule_widgets.dart';

/// P1: UI thuần nhận AsyncValue; nguồn fixture chỉ nằm ở entrypoint debug.
/// Widget trình bày nhận dữ liệu từ adapter API; fixture chỉ ở entrypoint debug.
class MentorScheduleScreen extends ConsumerWidget {
  const MentorScheduleScreen({
    super.key,
    required this.value,
    required this.selectedDay,
    required this.now,
    required this.onDaySelected,
    required this.onWeekChanged,
    required this.onRefresh,
    required this.onRetry,
    required this.onRoom,
    required this.onAttendance,
    this.onBack,
  });
  final AsyncValue<TeachingSchedule> value;
  final String selectedDay;
  final DateTime now;
  final ValueChanged<String> onDaySelected;
  final ValueChanged<int> onWeekChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final ValueChanged<TeachingEntry> onRoom, onAttendance;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final days = Dates.weekDays(selectedDay);
    final schedule = value.isLoading || value.hasError ? null : value.value;
    final today = schedule == null ? '' : Dates.localDay(now, schedule.timeZone);
    return StaffPage(
      onBack: onBack,
      title: t('mentor.schedule.title'),
      subtitle: t('mentor.schedule.week', {'from': Dates.dateOnly(days.first), 'to': Dates.dateOnly(days.last)}),
      headerExtra: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: t('mentor.schedule.previousWeek'),
                onPressed: () => onWeekChanged(-1),
                icon: const RotatedBox(quarterTurns: 2, child: Icon(Sym.chevronRight, color: StaffColors.surface)),
              ),
              TextButton(
                onPressed: today.isEmpty ? null : () => onDaySelected(today),
                child: Text(t('mentor.schedule.today'), style: StaffText.label.copyWith(color: StaffColors.surface)),
              ),
              IconButton(
                tooltip: t('mentor.schedule.nextWeek'),
                onPressed: () => onWeekChanged(1),
                icon: const Icon(Sym.chevronRight, color: StaffColors.surface),
              ),
            ],
          ),
          DayStrip(
            days: days,
            labels: t.list('mentor.schedule.days'),
            selectedDay: selectedDay,
            today: today,
            markedDays: {
              for (final e in schedule?.entries ?? <TeachingEntry>[])
                Dates.localDay(e.session.startsAt, schedule!.timeZone),
            },
            onSelected: onDaySelected,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${Dates.displayDay(selectedDay)}${selectedDay == today ? ' · ${t('mentor.schedule.today')}' : ''}',
                    style: StaffText.section,
                  ),
                ),
                if (schedule != null)
                  Text(
                    t('mentor.schedule.sessionCount', {'count': schedule.onDay(selectedDay).length}),
                    style: StaffText.caption,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...value.when(
              skipLoadingOnRefresh: false,
              loading: () => const <Widget>[Skeleton(height: 180), SizedBox(height: 12), Skeleton(height: 120)],
              error: (error, _) => <Widget>[
                StaffDataState(
                  title: t('mentor.schedule.loadError'),
                  description: t(errorKey(error)),
                  error: error,
                  onRetry: onRetry,
                ),
              ],
              data: (data) => data.onDay(selectedDay).isEmpty
                  ? <Widget>[
                      StaffDataState(
                        title: t('mentor.schedule.empty'),
                        description: t('mentor.schedule.emptyDescription'),
                      ),
                    ]
                  : <Widget>[
                      for (final entry in data.onDay(selectedDay))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MentorSessionCard(
                            entry: entry,
                            now: now,
                            timeZone: data.timeZone,
                            onRoom: onRoom,
                            onAttendance: onAttendance,
                          ),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
