import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';
import '../../../core/utils/format.dart';
import '../schedule/schedule_models.dart';
import '../session/session_context_models.dart';

class MentorNextSessionCard extends ConsumerWidget {
  const MentorNextSessionCard({
    super.key,
    required this.value,
    required this.now,
    required this.onViewSchedule,
    required this.onRetry,
    required this.onEnterRoom,
    this.room,
  });
  final AsyncValue<TeachingSchedule> value;
  final DateTime now;
  final VoidCallback onViewSchedule, onRetry;
  final ValueChanged<TeachingEntry> onEnterRoom;
  final AsyncValue<TeachingRoom>? room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onViewSchedule,
                    child: Text(t('mentor.home.viewSchedule'), style: StaffText.link),
                  ),
                ),
                value.when(
                  skipLoadingOnRefresh: false,
                  loading: () => const Skeleton(height: 125),
                  error: (error, _) => StaffDataState(
                    title: t('mentor.schedule.loadError'),
                    description: t(errorKey(error)),
                    error: error,
                    onRetry: onRetry,
                  ),
                  data: (data) {
                    final entry = data.nextToday(now);
                    if (entry == null) return Text(t('mentor.home.noSessions'), style: StaffText.bodyStrong);
                    final session = entry.session;
                    final contextRoom = room == null || room!.isLoading || room!.hasError ? null : room!.value;
                    final matchingRoom = contextRoom?.session.id == session.id ? contextRoom : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 86 * (MediaQuery.textScalerOf(context).scale(28) / 28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(Dates.time(session.startsAt, data.timeZone), style: StaffText.bigTime),
                                  Text(
                                    t('mentor.home.until', {'time': Dates.time(session.endsAt, data.timeZone)}),
                                    style: StaffText.caption,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StatusChip(
                                    t(session.isSubstitute ? 'mentor.session.substitute' : 'mentor.schedule.today'),
                                    tone: session.isSubstitute ? StatusTone.amber : StatusTone.teal,
                                    icon: session.isSubstitute ? Sym.swapHoriz : null,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(entry.className, style: StaffText.bodyStrong),
                                  const SizedBox(height: 6),
                                  Text(
                                    matchingRoom?.roomName ?? entry.roomName ?? t('mentor.session.noRoom'),
                                    style: StaffText.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (matchingRoom?.meetingUrl != null) ...[
                          const SizedBox(height: 20),
                          StaffButton(
                            label: t('mentor.home.enterMeet'),
                            icon: Sym.videocam,
                            onPressed: () => onEnterRoom(entry),
                          ),
                        ],
                        if (room?.hasError ?? false) ...[
                          const SizedBox(height: 12),
                          Text(t('mentor.room.loadError'), style: StaffText.caption),
                          TextButton(
                            onPressed: onRetry,
                            child: Text(t('common.retry'), style: StaffText.link),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: -14,
            top: -54,
            child: ExcludeSemantics(child: Image.asset('assets/illustrations/mindy-frog-peek.png', width: 112)),
          ),
        ],
      ),
    );
  }
}

class MentorSubstituteNotice extends ConsumerWidget {
  const MentorSubstituteNotice({super.key, required this.className, required this.onDismiss, required this.onOpen});
  final String className;
  final VoidCallback onDismiss, onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GlassCard(
        child: Row(
          children: [
            const Icon(Sym.swapHoriz, color: StaffColors.teal600),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton(
                onPressed: onOpen,
                child: Text(t('mentor.home.substituteNotice', {'name': className}), style: StaffText.label),
              ),
            ),
            IconButton(
              tooltip: t('mentor.home.dismiss'),
              onPressed: onDismiss,
              icon: const Icon(Sym.close, color: StaffColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
