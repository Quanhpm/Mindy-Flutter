import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/teaching_card.dart';
import '../../../core/utils/format.dart';
import 'schedule_models.dart';

StatusTone teachingTone(TeachingDisplayStatus status) => switch (status) {
  TeachingDisplayStatus.live => StatusTone.green,
  TeachingDisplayStatus.upcoming => StatusTone.teal,
  TeachingDisplayStatus.cancelled => StatusTone.red,
  TeachingDisplayStatus.completed || TeachingDisplayStatus.ended => StatusTone.gray,
};

/// Adapter model → thẻ Staff chung, cùng cách hiển thị trong lịch và dạy thay.
class MentorSessionCard extends ConsumerWidget {
  const MentorSessionCard({
    super.key,
    required this.entry,
    required this.now,
    required this.timeZone,
    required this.onRoom,
    required this.onAttendance,
    this.onTools,
    this.substitutePage = false,
  });
  final TeachingEntry entry;
  final DateTime now;
  final String timeZone;
  final ValueChanged<TeachingEntry> onRoom, onAttendance;
  final ValueChanged<TeachingEntry>? onTools;
  final bool substitutePage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final session = entry.session;
    final status = session.displayStatus(now);
    return TeachingCard(
      startTime: Dates.time(session.startsAt, timeZone),
      endTime: Dates.time(session.endsAt, timeZone),
      title: entry.className,
      subtitle: '${entry.roomName ?? t('mentor.session.noRoom')} · ${session.title}',
      status: t('mentor.session.status.${status.name}'),
      tone: teachingTone(status),
      substituteLabel: !substitutePage && session.isSubstitute ? t('mentor.session.substitute') : null,
      dayLabel: substitutePage ? Dates.displayDay(Dates.localDay(session.startsAt, timeZone)) : null,
      mentorLabel: substitutePage
          ? t('mentor.session.primaryMentor', {
              'name': session.primaryMentor.displayName ?? t('mentor.session.unnamedMentor'),
            })
          : null,
      attendanceLabel: t('mentor.session.attendance'),
      roomLabel: t('mentor.session.enterRoom'),
      toolsLabel: t('mentor.operations.tools'),
      onTools: onTools == null ? null : () => onTools!(entry),
      onAttendance: status == TeachingDisplayStatus.live ? () => onAttendance(entry) : null,
      onRoom: status == TeachingDisplayStatus.live ? () => onRoom(entry) : null,
    );
  }
}
