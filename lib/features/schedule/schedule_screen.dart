import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import '../my_classes/my_classes_models.dart';
import 'schedule_models.dart';
import 'schedule_providers.dart';

/// Lịch học tuần - `schedule/ScheduleScreen.tsx` + `useScheduleController.ts`.
/// Tuần / chọn ngày / "Hôm nay" / kéo để làm mới. Hàng buổi học CHỈ ĐỌC (như RN).
/// TODO(UI): port timeline dọc + header tháng theo ScheduleScreen.tsx.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  String? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final anchor = ref.watch(scheduleAnchorProvider);
    final zone = ref.watch(scheduleZoneProvider);
    final week = ref.watch(scheduleWeekProvider);
    final days = Dates.weekDays(anchor);
    final today = Dates.localDay(DateTime.now(), week.value?.timeZone ?? zone);
    final selected = _selectedDay != null && days.contains(_selectedDay) ? _selectedDay! : (days.contains(today) ? today : days.first);
    final labels = t.list('schedule.days');

    // Response trả timeZone khác -> tính lại tuần theo múi giờ server
    ref.listen(scheduleWeekProvider, (_, next) {
      final z = next.value?.timeZone;
      if (z != null && z != ref.read(scheduleZoneProvider)) ref.read(scheduleZoneProvider.notifier).set(z);
    });

    return Scaffold(
      bottomNavigationBar: const AppTabBar(selected: HomeTab.schedule),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(scheduleWeekProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(t('schedule.title'), style: AppText.sectionTitle(AppColors.forest)),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextLink(t('schedule.previous'), onTap: () => ref.read(scheduleAnchorProvider.notifier).shiftWeek(-1)),
                  Expanded(
                    child: Text(
                      t('schedule.week', {'from': Dates.dateOnly(days.first), 'to': Dates.dateOnly(days.last)}),
                      textAlign: TextAlign.center,
                      style: AppText.label(AppColors.forest),
                    ),
                  ),
                  TextLink(t('schedule.next'), onTap: () => ref.read(scheduleAnchorProvider.notifier).shiftWeek(1)),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextLink(t('schedule.today'), onTap: () {
                  ref.read(scheduleAnchorProvider.notifier).today();
                  setState(() => _selectedDay = today);
                }),
              ),
              const SizedBox(height: 8),
              // ---- 7 ngày
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Pressable(
                        onTap: () => setState(() => _selectedDay = days[i]),
                        selected: days[i] == selected,
                        semanticLabel: Dates.displayDay(days[i]),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: days[i] == selected ? AppColors.mint : AppColors.soft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(children: [
                            Text(i < labels.length ? labels[i] : '',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: days[i] == selected ? AppColors.canvas : AppColors.muted)),
                            Text(days[i].substring(8),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: days[i] == selected ? AppColors.canvas : AppColors.forest)),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AsyncView(
                value: week,
                onRetry: () => ref.invalidate(scheduleWeekProvider),
                data: (w) {
                  if (w.items.isEmpty) {
                    return ScreenState(title: t('schedule.state.empty'), description: t('schedule.state.description'));
                  }
                  final ofDay = w.items.where((s) => Dates.localDay(s.startsAt, w.timeZone) == selected).toList();
                  if (ofDay.isEmpty) {
                    return Text(t('schedule.noSessionsOnDay', {'day': Dates.displayDay(selected)}));
                  }
                  return Column(children: [for (final s in ofDay) _row(t, s, w.timeZone)]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(Translator t, ScheduleSession s, String zone) {
    final cancelled = s.sessionStatus == SessionStatus.CANCELLED;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cancelled ? AppColors.peach : AppColors.canvas,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${Dates.time(s.startsAt, zone)} ${t('schedule.timeSeparator')} ${Dates.time(s.endsAt, zone)}',
              style: AppText.label(AppColors.mint)),
          Text(s.sessionTitle, style: AppText.label(AppColors.forest)),
          Text('${s.courseTitle} · ${s.classCode} · ${t('schedule.delivery.${s.deliveryMode.name}')}',
              style: AppText.caption(AppColors.muted)),
          if (s.roomName != null) Text(t('schedule.room', {'room': s.roomName}), style: AppText.caption(AppColors.muted)),
          if (s.mentorName != null)
            Text(t('schedule.mentor', {'name': s.mentorName}), style: AppText.caption(AppColors.muted)),
          if (cancelled)
            Text(t('learning.sessionStatus.CANCELLED'), style: const TextStyle(color: AppColors.statusRed)),
        ],
      ),
    );
  }
}
