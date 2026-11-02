import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/i18n.dart';
import '../../core/network/api_error.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/cover_image.dart';
import '../../core/ui/icon.dart';
import '../../core/ui/learning_layout.dart';
import '../../core/ui/states.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/format.dart';
import '../courses/courses_models.dart';
import '../schedule/schedule_providers.dart';
import 'learning_hero.dart';
import 'meeting_button.dart';
import 'my_classes_models.dart';
import 'my_classes_providers.dart';
import 'participants_sheet.dart';
import 'session_detail_screen.dart';

/// Chi tiết lớp học - port 1:1 từ `MindyMobile/src/modules/my-classes/ClassDetailScreen.tsx`.
class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({
    super.key,
    required this.classId,
    this.sessionId,
  });

  final String classId;
  final String? sessionId;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  late String? _selectedSessionId = widget.sessionId;
  bool _descriptionOpen = false;
  bool _joining = false;
  bool _joinError = false;

  @override
  void didUpdateWidget(ClassDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionId != oldWidget.sessionId) {
      _selectedSessionId = widget.sessionId;
    }
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .toList();
    if (parts.isEmpty) return '?';
    final slice = parts.length > 2 ? parts.sublist(parts.length - 2) : parts;
    return slice.join().toUpperCase();
  }

  static String? _meetingLink(ClassDetail detail, ClassSession session) {
    if (detail.accessMode != AccessMode.FULL ||
        detail.deliveryMode != DeliveryMode.ONLINE ||
        session.status == SessionStatus.CANCELLED) {
      return null;
    }
    final raw = session.meetingUrl ?? detail.meetingUrl;
    if (raw == null || !RegExp(r'^https?://[^\s]+$', caseSensitive: false).hasMatch(raw)) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.host.isNotEmpty && uri.userInfo.isEmpty) {
      return raw;
    }
    return null;
  }

  Future<void> _join(String url) async {
    if (_joining) return;
    setState(() {
      _joining = true;
      _joinError = false;
    });
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        setState(() => _joinError = true);
      }
    } catch (_) {
      if (mounted) setState(() => _joinError = true);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _openParticipants(String? mentorName, String classCode) {
    showAppSheet<void>(
      context,
      (_) => ClassParticipantsSheet(
        mentorName: mentorName,
        classCode: classCode,
      ),
      initialSize: 0.55,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final detailAsync = ref.watch(classDetailProvider(widget.classId));
    final timeZone = ref.watch(learningTimeZoneProvider).value ?? 'Asia/Ho_Chi_Minh';
    ref.watch(appNowProvider); // Foreground clock sync

    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compact = width <= 360 || textScale >= 1.3;

    final isDenied = detailAsync.hasError &&
        (detailAsync.error is ApiError &&
            ['CLASS_ACCESS_DENIED', 'CLASS_PREVIEW_DENIED', 'CLASS_NOT_FOUND']
                .contains((detailAsync.error as ApiError).code));

    final data = detailAsync.value?.detail;
    final enrollment = detailAsync.value?.enrollment;
    final verified = data != null && !isDenied && detailAsync.hasValue;

    final sessions = data?.sessions ?? const [];
    final now = DateTime.now();
    final activeSession = nextLearningSession(sessions, now);

    // Selected session view
    if (_selectedSessionId != null && data != null && verified) {
      final selectedSession = sessions.where((s) => s.id == _selectedSessionId).firstOrNull;
      if (selectedSession != null) {
        final unit = data.units.where((u) => u.sessions.any((s) => s.id == _selectedSessionId)).firstOrNull;
        final link = _meetingLink(data, selectedSession);
        return SessionDetailScreen(
          session: selectedSession,
          classCode: data.code,
          totalSessions: sessions.length,
          unitTitle: unit?.title ?? '',
          mentorName: data.mentorName ?? t('classDetail.noMentor'),
          deliveryMode: data.deliveryMode,
          timeZone: timeZone,
          joining: _joining,
          joinError: _joinError,
          onJoin: (link != null && selectedSession.status != SessionStatus.COMPLETED)
              ? () => _join(link)
              : null,
          onClose: () {
            setState(() {
              _selectedSessionId = null;
              _joinError = false;
            });
          },
        );
      }
    }

    final mentorName = data?.mentorName ?? t('classDetail.noMentor');

    // Preferred session for footer meet button
    final preferred = activeSession ??
        sessions.where((s) => s.status == SessionStatus.IN_PROGRESS && _meetingLink(data!, s) != null).firstOrNull ??
        sessions.where((s) => s.status == SessionStatus.SCHEDULED && _meetingLink(data!, s) != null).firstOrNull;
    final footerUrl = (data != null && preferred != null && verified) ? _meetingLink(data, preferred) : null;

    final footer = (data != null && verified)
        ? Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_joinError) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      t('classDetail.linkError'),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        color: AppColors.headsup,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Semantics(
                      button: true,
                      label: t('classDetail.participants.open'),
                      child: InkWell(
                        key: const Key('class-detail-participants'),
                        borderRadius: BorderRadius.circular(27),
                        onTap: () => _openParticipants(data.mentorName, data.code),
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.canvas,
                            border: Border.all(color: AppColors.line),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x331D5B57),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.sunshine,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _initials(mentorName),
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.mint,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (footerUrl != null)
                      MeetingButton(
                        testId: 'class-detail-join',
                        joining: _joining,
                        onPress: () => _join(footerUrl),
                      ),
                  ],
                ),
              ],
            ),
          )
        : null;

    final header = (!verified || isDenied)
        ? Container(
            color: AppColors.forestDeep,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Semantics(
              button: true,
              label: t('learning.back'),
              child: InkWell(
                key: const Key('class-detail-back'),
                onTap: () => context.canPop() ? context.pop() : context.go(Routes.home),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: MindyIcon(MindyIconName.back, light: true, size: 24),
                  ),
                ),
              ),
            ),
          )
        : null;

    return LearningLayout(
      prefix: 'class-detail',
      title: t('classDetail.title'),
      showTitle: false,
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.home),
      tintedStatusBar: true,
      statusTintTone: 'forest',
      contentPadding: EdgeInsets.zero,
      onRefresh: () async => ref.refresh(classDetailProvider(widget.classId).future),
      footer: footer,
      floatingFooter: true,
      header: header,
      children: isDenied
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ScreenState(
                title: t(
                  (detailAsync.error is ApiError && (detailAsync.error as ApiError).code == 'CLASS_NOT_FOUND')
                      ? 'classDetail.notFound'
                      : 'classDetail.denied',
                ),
                description: t('classDetail.returnToList'),
                requestId: requestIdOf(detailAsync.error ?? Object()),
              ),
            )
          : LearningState<({ClassDetail detail, Enrollment enrollment})>(
              asyncValue: detailAsync,
              prefix: 'class-detail',
              empty: data == null,
              onRetry: () => ref.refresh(classDetailProvider(widget.classId).future),
              child: data == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hero
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            LearningHero(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 52),
                              borderRadius: BorderRadius.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Back Button
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Semantics(
                                      button: true,
                                      label: t('learning.back'),
                                      child: InkWell(
                                        key: const Key('class-detail-back'),
                                        onTap: () => context.canPop() ? context.pop() : context.go(Routes.home),
                                        child: const SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: Center(
                                            child: MindyIcon(MindyIconName.back, light: true, size: 24),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Cover + Info
                                  if (compact) ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildCover(data, enrollment, 88),
                                        const SizedBox(height: 16),
                                        _buildHeroMeta(context, t, data, enrollment),
                                      ],
                                    ),
                                  ] else ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        _buildCover(data, enrollment, 112),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildHeroMeta(context, t, data, enrollment),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Decorative mint circle
                            Positioned(
                              top: 30,
                              right: -56,
                              child: IgnorePointer(
                                child: Container(
                                  width: 224,
                                  height: 224,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.mint.withValues(alpha: 0.25),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Body
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.canvas,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Cash Preview Box
                                if (data.accessMode == AccessMode.CASH_PREVIEW) ...[
                                  Container(
                                    key: const Key('class-detail-preview'),
                                    decoration: BoxDecoration(
                                      color: AppColors.sunshine,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t('classDetail.preview'),
                                          style: const TextStyle(
                                            fontFamily: 'Nunito',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: AppColors.forest,
                                          ),
                                        ),
                                        if (data.expiresAt != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            t('myClasses.expires', {
                                              'date': Dates.instant(data.expiresAt!, timeZone),
                                            }),
                                            style: const TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 12,
                                              color: AppColors.forest,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Stats Row
                                _buildStats(t, data, sessions.length, compact),
                                const SizedBox(height: 20),

                                // Description
                                _buildDescription(t, data, enrollment?.courseTitle),
                                const SizedBox(height: 20),

                                // Mentor Row
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.soft,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.sunshine,
                                          border: Border.all(color: AppColors.canvas, width: 2),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _initials(mentorName),
                                          style: const TextStyle(
                                            fontFamily: 'Nunito',
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: AppColors.mint,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t('classDetail.mentorLabel'),
                                              style: const TextStyle(
                                                fontFamily: 'Nunito',
                                                fontSize: 11,
                                                color: AppColors.muted,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              mentorName,
                                              style: const TextStyle(
                                                fontFamily: 'Nunito',
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: AppColors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Sessions Heading
                                Row(
                                  children: [
                                    Expanded(
                                      child: Semantics(
                                        header: true,
                                        child: Text(
                                          t('classDetail.sessionsLabel'),
                                          style: const TextStyle(
                                            fontFamily: 'Nunito',
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                            color: AppColors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      t('classDetail.sessionCount', {'count': sessions.length}),
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.sessionId != null &&
                                    !sessions.any((s) => s.id == widget.sessionId)) ...[
                                  const SizedBox(height: 8),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      t('classDetail.missingSession'),
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 14,
                                        color: AppColors.headsup,
                                      ),
                                    ),
                                  ),
                                ],
                                if (sessions.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    t('classDetail.noUnits'),
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 14,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],

                                // Session rows
                                const SizedBox(height: 8),
                                for (int i = 0; i < sessions.length; i++) ...[
                                  _buildSessionRow(t, sessions[i], i, activeSession?.id, timeZone, now, compact),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildCover(ClassDetail data, Enrollment? enrollment, double width) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: width,
        height: width * (4 / 3),
        child: CoverImage(
          url: enrollment?.courseImageUrl,
          label: enrollment?.courseTitle ?? data.name,
          fallback: const CourseCover(index: 0),
          hideLabel: true,
        ),
      ),
    );
  }

  Widget _buildHeroMeta(BuildContext context, Translator t, ClassDetail data, Enrollment? enrollment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.code,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 24,
            height: 28 / 24,
            color: AppColors.canvas,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MindyIcon(MindyIconName.monitor, light: true, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                enrollment?.courseTitle ?? data.name,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14.5,
                  height: 20 / 14.5,
                  color: AppColors.canvas,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.coral,
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            t('learning.classStatus.${data.classStatus.name}'),
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppColors.canvas,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats(Translator t, ClassDetail data, int sessionCount, bool compact) {
    final stats = [
      (value: '$sessionCount', label: t('classDetail.sessionsLabel')),
      (value: Dates.dateOnly(data.startDate), label: t('classDetail.startDate')),
      (value: Dates.dateOnly(data.endDate), label: t('classDetail.endDate')),
      (value: t('schedule.delivery.${data.deliveryMode.name}'), label: t('classDetail.deliveryLabel')),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: [
        for (final s in stats)
          SizedBox(
            width: compact ? 140 : 70,
            child: Column(
              children: [
                Text(
                  s.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDescription(Translator t, ClassDetail data, String? courseTitle) {
    final text = data.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: _descriptionOpen ? null : 2,
          overflow: _descriptionOpen ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            height: 23 / 14,
            color: AppColors.black,
          ),
        ),
        if (text.length > 80) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () => setState(() => _descriptionOpen = !_descriptionOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                t(_descriptionOpen ? 'classDetail.less' : 'classDetail.more'),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.headsup,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSessionRow(
    Translator t,
    ClassSession item,
    int index,
    String? activeSessionId,
    String timeZone,
    DateTime now,
    bool compact,
  ) {
    final active = item.id == activeSessionId;
    final displayStatus = sessionDisplayStatusRN(item, now);
    final day = Dates.localDay(item.startsAt, timeZone);
    final dayIndex = (DateTime.parse('${day}T12:00:00Z').weekday - 1) % 7;
    final isToday = day == Dates.localDay(now, timeZone) || item.startsAt.isBefore(now);

    final statusLabel = active
        ? t(isToday ? 'classDetail.rowToday' : 'classDetail.rowUpcoming')
        : displayStatus == SessionStatus.SCHEDULED
            ? t('classDetail.rowUpcoming')
            : t('learning.sessionStatus.${displayStatus.name}');

    final sessionMeta =
        '${t('classDetail.sessionNumber', {'number': item.sessionNumber})} · ${t('schedule.days.$dayIndex')} ${Dates.dateOnly(day)} · ${Dates.time(item.startsAt, timeZone)} – ${Dates.time(item.endsAt, timeZone)}';

    return Container(
      decoration: BoxDecoration(
        color: active ? AppColors.peach : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: active ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      margin: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        button: true,
        selected: active,
        label: '${item.title}, $sessionMeta, $statusLabel',
        child: InkWell(
          key: Key('class-detail-session-${item.id}'),
          onTap: () {
            setState(() {
              _selectedSessionId = item.id;
              _joinError = false;
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: displayStatus == SessionStatus.COMPLETED
                          ? AppColors.mint
                          : active
                              ? AppColors.coral
                              : AppColors.soft,
                    ),
                    alignment: Alignment.center,
                    child: displayStatus == SessionStatus.COMPLETED
                        ? const MindyIcon(MindyIconName.check, light: true, size: 17)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 14,
                              color: active ? AppColors.canvas : AppColors.forest,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                            fontSize: 13,
                            height: 18 / 13,
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sessionMeta,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            height: 16 / 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: (active || displayStatus == SessionStatus.CANCELLED)
                              ? AppColors.headsup
                              : AppColors.mint,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ExcludeSemantics(
                        child: Text(
                          t('schedule.next'),
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.mint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
