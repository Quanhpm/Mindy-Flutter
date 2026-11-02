import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/learning_layout.dart';
import '../../core/ui/pressable.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/format.dart';
import '../courses/courses_models.dart';
import '../my_classes/my_classes_models.dart';
import 'schedule_models.dart';
import 'schedule_providers.dart';

/// Màn hình lịch học của học viên - port từ `ScheduleScreen.tsx`.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _stripController = ScrollController();
  final Map<String, GlobalKey> _groupKeys = {};

  String? _selectedDay;
  String? _selectedWeek;

  @override
  void dispose() {
    _scrollController.dispose();
    _stripController.dispose();
    super.dispose();
  }

  void _chooseDay(String day, List<String> days, double dayWidth) {
    final first = days.first;
    setState(() {
      _selectedWeek = first;
      _selectedDay = day;
    });

    final index = days.indexOf(day);
    if (index >= 0 && _stripController.hasClients) {
      final targetX = math.max(0.0, (index - 3) * dayWidth);
      _stripController.animateTo(
        targetX,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    final key = _groupKeys[day];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final zoneAsync = ref.watch(learningTimeZoneProvider);
    final anchor = ref.watch(scheduleAnchorProvider);
    final weekAsync = ref.watch(scheduleWeekProvider);
    final now = ref.watch(appNowProvider).value ?? DateTime.now();

    final timeZone = zoneAsync.value ?? 'UTC';
    final today = Dates.localDay(now, timeZone);
    final days = Dates.weekDays(anchor);
    final first = days.first;
    final last = days.last;

    // Khởi tạo lựa chọn ban đầu nếu đang ở tuần có hôm nay
    if (_selectedWeek != first) {
      _selectedWeek = first;
      _selectedDay = days.contains(today) ? today : null;
    }

    final selected = _selectedWeek == first ? _selectedDay : null;

    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final fontScale = mq.textScaler.scale(1);
    final compact = width <= 360 || fontScale >= 1.3;
    final dayWidth = math.max(44.0, (width - 32.0) / 7.0);

    // Tính chuỗi tháng
    final monthNum = int.tryParse(anchor.substring(5, 7)) ?? 1;
    final yearStr = anchor.substring(0, 4);
    final monthName = DateFormat('MMMM', t.locale.languageCode).format(DateTime.parse('${anchor}T12:00:00Z'));
    final monthText = t('schedule.month', {
      'month': t.locale.languageCode.startsWith('vi') ? monthNum : monthName,
      'year': yearStr,
    });

    final items = weekAsync.value?.items ?? const <ScheduleSession>[];
    final groups = days.map((day) {
      final daySessions = items
          .where((s) => Dates.localDay(s.startsAt, timeZone) == day)
          .toList()
        ..sort((a, b) {
          final diff = a.startsAt.compareTo(b.startsAt);
          return diff != 0 ? diff : a.sessionId.compareTo(b.sessionId);
        });
      return (day: day, index: days.indexOf(day), sessions: daySessions);
    }).toList();

    // Calendar Header
    final calendarHeader = Container(
      color: AppColors.canvas,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Pressable(
                  key: const Key('schedule-prev-week'),
                  semanticLabel: t('schedule.previousWeek'),
                  onTap: () {
                    ref.read(scheduleAnchorProvider.notifier).shiftWeek(-1);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      t('schedule.previous'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mint,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Pressable(
                    key: const Key('schedule-today'),
                    semanticLabel: '$monthText, ${t('schedule.week', {'from': Dates.displayDay(first), 'to': Dates.displayDay(last)})}',
                    onTap: () {
                      ref.read(scheduleAnchorProvider.notifier).today();
                      _chooseDay(today, Dates.weekDays(today), dayWidth);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        monthText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                Pressable(
                  key: const Key('schedule-next-week'),
                  semanticLabel: t('schedule.nextWeek'),
                  onTap: () {
                    ref.read(scheduleAnchorProvider.notifier).shiftWeek(1);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      t('schedule.next'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            padding: const EdgeInsets.only(bottom: 10),
            child: SingleChildScrollView(
              controller: _stripController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final g in groups)
                    _buildDayButton(
                      t,
                      g.day,
                      g.index,
                      g.sessions,
                      selected == g.day,
                      today == g.day,
                      dayWidth,
                      () => _chooseDay(g.day, days, dayWidth),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final selectedGroup = groups.where((g) => g.day == selected).firstOrNull;
    final hasNoSessionsOnSelected = selected != null && (selectedGroup?.sessions.isEmpty ?? true);

    return LearningLayout(
      title: t('schedule.title'),
      prefix: 'schedule',
      showTitle: false,
      tintedStatusBar: true,
      header: calendarHeader,
      contentPadding: const EdgeInsets.only(bottom: 20),
      tab: HomeTab.schedule,
      onTab: (tab) => goTab(context, tab),
      refreshing: weekAsync.isLoading,
      scrollController: _scrollController,
      onRefresh: () async {
        ref.invalidate(learningTimeZoneProvider);
        ref.invalidate(scheduleWeekProvider);
      },
      children: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasNoSessionsOnSelected)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                t('schedule.noSessionsOnDay', {'day': Dates.displayDay(selected)}),
                key: const Key('schedule-empty-day'),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
            ),
          LearningState<ScheduleWeek>(
            asyncValue: weekAsync,
            prefix: 'schedule',
            empty: items.isEmpty,
            onRetry: () => ref.invalidate(scheduleWeekProvider),
            child: Column(
              children: [
                for (var groupIndex = 0; groupIndex < groups.length; groupIndex++)
                  if (groups[groupIndex].sessions.isNotEmpty)
                    _buildDayGroup(
                      t,
                      groups[groupIndex].day,
                      groups[groupIndex].index,
                      groups[groupIndex].sessions,
                      groupIndex,
                      compact,
                      timeZone,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayButton(
    Translator t,
    String day,
    int index,
    List<ScheduleSession> sessions,
    bool isSelected,
    bool isToday,
    double width,
    VoidCallback onTap,
  ) {
    final labels = t.list('schedule.days');
    final dayNumber = int.tryParse(day.substring(8)) ?? 1;

    return Pressable(
      key: Key('schedule-day-$day'),
      selected: isSelected,
      semanticLabel: t('schedule.dayLabel', {
        'day': Dates.displayDay(day),
        'count': sessions.length,
        'today': isToday ? t('schedule.today') : '',
      }),
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labels.length > index ? labels[index] : '',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.forest : Colors.transparent,
                ),
                child: Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppColors.canvas : AppColors.black,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sessions.isEmpty
                      ? Colors.transparent
                      : sessions.any((s) => s.sessionStatus == SessionStatus.CANCELLED)
                          ? AppColors.coral
                          : AppColors.mint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayGroup(
    Translator t,
    String day,
    int dayIndex,
    List<ScheduleSession> sessions,
    int groupIndex,
    bool compact,
    String timeZone,
  ) {
    _groupKeys[day] ??= GlobalKey();
    final dayPart = day.substring(8);
    final monthPart = day.substring(5, 7);
    final isOdd = groupIndex % 2 == 1;

    return Container(
      key: _groupKeys[day],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cột ngày bên trái
          Container(
            width: compact ? 56 : 72,
            padding: const EdgeInsets.only(top: 16, left: 4, right: 4),
            decoration: BoxDecoration(
              color: isOdd ? AppColors.peach : AppColors.soft,
            ),
            child: Column(
              children: [
                Text(
                  compact ? '$dayPart\n/$monthPart' : '$dayPart/$monthPart',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 17 : 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('schedule.weekdays.$dayIndex'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Cột danh sách buổi bên phải
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 16),
              child: Column(
                children: [
                  for (final session in sessions)
                    _buildSessionItem(t, session, compact, timeZone, day),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(
    Translator t,
    ScheduleSession session,
    bool compact,
    String timeZone,
    String currentDay,
  ) {
    final isCancelled = session.sessionStatus == SessionStatus.CANCELLED;
    final endsDay = Dates.localDay(session.endsAt, timeZone);

    return Pressable(
      key: Key('schedule-session-${session.sessionId}'),
      onTap: () {
        context.push(Routes.classDetail(session.classId, sessionId: session.sessionId));
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 4,
                color: isCancelled ? AppColors.coral : AppColors.mint,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: 10),
          child: compact
              ? _buildCompactSession(t, session, isCancelled, timeZone, endsDay, currentDay)
              : _buildNormalSession(t, session, isCancelled, timeZone, endsDay, currentDay),
        ),
      ),
    );
  }

  Widget _buildCompactSession(
    Translator t,
    ScheduleSession session,
    bool isCancelled,
    String timeZone,
    String endsDay,
    String currentDay,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hàng thời gian
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: isCancelled ? AppColors.peach : AppColors.line,
              ),
              child: Text(
                t('classDetail.sessionNumber', {'number': session.sessionNumber}),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ),
            Text(
              Dates.time(session.startsAt, timeZone),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            Text(
              t('schedule.timeSeparator'),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
            Text(
              Dates.time(session.endsAt, timeZone),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Thân chi tiết
        _buildSessionBody(t, session, isCancelled, timeZone, endsDay, currentDay),
      ],
    );
  }

  Widget _buildNormalSession(
    Translator t,
    ScheduleSession session,
    bool isCancelled,
    String timeZone,
    String endsDay,
    String currentDay,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cột giờ bên trái (44px)
        SizedBox(
          width: 44,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: isCancelled ? AppColors.peach : AppColors.line,
                ),
                child: Text(
                  t('classDetail.sessionNumber', {'number': session.sessionNumber}),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                Dates.time(session.startsAt, timeZone),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              Text(
                t('schedule.timeSeparator'),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
              Text(
                Dates.time(session.endsAt, timeZone),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Thân chi tiết bên phải
        Expanded(
          child: _buildSessionBody(t, session, isCancelled, timeZone, endsDay, currentDay),
        ),
      ],
    );
  }

  Widget _buildSessionBody(
    Translator t,
    ScheduleSession session,
    bool isCancelled,
    String timeZone,
    String endsDay,
    String currentDay,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mã lớp
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppColors.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('schedule.classCode'),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.muted,
                ),
              ),
              Text(
                session.classCode,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Tiêu đề buổi
        Text(
          session.sessionTitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 6),

        // Phòng và giảng viên
        Text(
          t('schedule.room', {
            'room': session.deliveryMode == DeliveryMode.ONLINE ? '' : (session.roomName ?? t('classDetail.noRoom')),
          }),
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          t('schedule.mentor', {
            'name': session.mentorName ?? t('classDetail.noMentor'),
          }),
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.muted,
          ),
        ),
        if (endsDay != currentDay) ...[
          const SizedBox(height: 2),
          Text(
            Dates.instant(session.endsAt, timeZone),
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.muted,
            ),
          ),
        ],
        const SizedBox(height: 6),

        // Tags
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isCancelled ? AppColors.peach : AppColors.line,
              ),
              child: Text(
                t('learning.sessionStatus.${session.sessionStatus.name}'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isCancelled ? AppColors.headsup : AppColors.muted,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: session.deliveryMode == DeliveryMode.ONLINE ? AppColors.line : AppColors.coral,
                ),
              ),
              child: Text(
                t('schedule.delivery.${session.deliveryMode.name}'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: session.deliveryMode == DeliveryMode.ONLINE ? AppColors.mint : AppColors.headsup,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
