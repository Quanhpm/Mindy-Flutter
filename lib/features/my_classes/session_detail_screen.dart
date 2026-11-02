import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/icon.dart';
import '../../core/utils/format.dart';
import '../courses/courses_models.dart';
import 'meeting_button.dart';
import 'my_classes_models.dart';

/// Chi tiết buổi học - port 1:1 từ `MindyMobile/src/modules/my-classes/SessionDetailScreen.tsx`.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({
    super.key,
    required this.session,
    required this.classCode,
    required this.totalSessions,
    required this.unitTitle,
    required this.mentorName,
    required this.deliveryMode,
    required this.timeZone,
    required this.onClose,
    this.onJoin,
    this.joining = false,
    this.joinError = false,
  });

  final ClassSession session;
  final String classCode;
  final int totalSessions;
  final String unitTitle;
  final String mentorName;
  final DeliveryMode deliveryMode;
  final String timeZone;
  final VoidCallback onClose;
  final VoidCallback? onJoin;
  final bool joining;
  final bool joinError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compact = width <= 360 || textScale >= 1.3;

    final day = Dates.localDay(session.startsAt, timeZone);
    final parsedDay = DateTime.parse('${day}T12:00:00Z');
    final dayIndex = (parsedDay.weekday - 1) % 7; // 0 = Mon, 6 = Sun

    final facts = [
      (
        label: t('classDetail.session.date'),
        value: '${t('schedule.days.$dayIndex')} ${Dates.displayDay(day)}',
      ),
      (
        label: t('classDetail.session.time'),
        value: '${Dates.time(session.startsAt, timeZone)} – ${Dates.time(session.endsAt, timeZone)}',
      ),
      (
        label: t('classDetail.mentorLabel'),
        value: mentorName,
      ),
      (
        label: t('classDetail.deliveryLabel'),
        value: t('schedule.delivery.${deliveryMode.name}'),
      ),
      if (deliveryMode == DeliveryMode.OFFLINE)
        (
          label: t('classDetail.session.room'),
          value: session.roomName ?? t('classDetail.noRoom'),
        ),
    ];

    final isCancelled = session.status == SessionStatus.CANCELLED;
    final statusStr = t('learning.sessionStatus.${sessionDisplayStatusRN(session, DateTime.now()).name}');

    return Scaffold(
      key: const Key('class-session-screen'),
      backgroundColor: AppColors.coverASoft,
      body: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header & Info in coverASoft
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Semantics(
                        button: true,
                        label: t('learning.back'),
                        child: InkWell(
                          key: const Key('class-session-close'),
                          borderRadius: BorderRadius.circular(22),
                          onTap: onClose,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.canvas,
                            ),
                            alignment: Alignment.center,
                            child: MindyIcon(
                              MindyIconName.back,
                              size: compact ? 17 : 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t('classDetail.session.heading', {
                            'code': classCode,
                            'number': session.sessionNumber,
                            'total': totalSessions,
                          }),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text(
                      statusStr,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: isCancelled ? AppColors.headsup : AppColors.mint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      session.title,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 28 / 22,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('classDetail.session.unit', {'title': unitTitle}),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),

            // White Canvas Body
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          // 2-column facts grid
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final fact in facts)
                                SizedBox(
                                  width: (width - 42) / 2,
                                  child: Container(
                                    constraints: const BoxConstraints(minHeight: 64),
                                    decoration: BoxDecoration(
                                      color: AppColors.soft,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          fact.label,
                                          style: const TextStyle(
                                            fontFamily: 'Nunito',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11.5,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          fact.value,
                                          style: const TextStyle(
                                            fontFamily: 'Nunito',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            height: 20 / 14,
                                            color: AppColors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (Dates.localDay(session.endsAt, timeZone) != day) ...[
                            const SizedBox(height: 12),
                            Text(
                              Dates.instant(session.endsAt, timeZone),
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                          if (joinError) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                t('classDetail.linkError'),
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 14,
                                  color: AppColors.headsup,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Semantics(
                            header: true,
                            child: Text(
                              t('classDetail.session.content'),
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppColors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            t('classDetail.session.noContent'),
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              height: 24 / 14,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            header: true,
                            child: Text(
                              t('classDetail.session.objectives'),
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppColors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            t('classDetail.session.noObjectives'),
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              height: 24 / 14,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Buttons
                    Container(
                      color: AppColors.canvas,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Semantics(
                              button: true,
                              label: t('classDetail.session.materials'),
                              hint: t('account.unavailable'),
                              enabled: false,
                              child: Opacity(
                                opacity: 0.6,
                                child: Container(
                                  key: const Key('class-session-materials'),
                                  constraints: const BoxConstraints(minHeight: 54),
                                  decoration: BoxDecoration(
                                    color: AppColors.forest,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x401D5B57), // shadow-forest/25
                                        blurRadius: 16,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 8 : 16,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: compact ? 28 : 36,
                                        height: compact ? 28 : 36,
                                        decoration: const BoxDecoration(
                                          color: AppColors.mint,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: MindyIcon(
                                          MindyIconName.document,
                                          light: true,
                                          size: compact ? 17 : 18,
                                        ),
                                      ),
                                      SizedBox(width: compact ? 6 : 10),
                                      Flexible(
                                        child: Text(
                                          t('classDetail.session.materials'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontWeight: FontWeight.w800,
                                            fontSize: compact ? 13 : 14,
                                            color: AppColors.canvas,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (onJoin != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: MeetingButton(
                                testId: 'class-session-join',
                                joining: joining,
                                onPress: onJoin!,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
