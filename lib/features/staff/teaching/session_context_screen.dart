import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_entry_points.dart';
import '../attendance/audits_screen.dart';
import '../attendance/recovery_screen.dart';
import '../operations/session_operations.dart';
import 'class_detail_screens.dart';
import 'classes_screens.dart';
import 'teaching_format.dart';
import 'teaching_models.dart';
import 'teaching_query.dart';
import 'teaching_widgets.dart';

/// Bộ tab chi tiết buổi dùng chung với màn Lịch sử / Khôi phục điểm danh (`detailTabs` RN).
typedef StaffDetailTabs = ({
  String title,
  List<({String value, String label})> tabs,
  String tab,
  ValueChanged<String> onTab,
});

/// Clone `SessionContextScreen.tsx`.
/// Mentor: tab Tổng quan / Học viên / Tài liệu. Quản lý: Tổng quan / Điểm danh / Lịch sử / Khôi phục.
/// Thêm (Flutter giữ lại): lối vào Bài tập code của buổi cho Mentor.
class StaffSessionContextScreen extends ConsumerStatefulWidget {
  const StaffSessionContextScreen({
    super.key,
    required this.sessionId,
    required this.manager,
    this.classTitle,
    this.initialTab,
  });

  final String sessionId;
  final bool manager;
  final String? classTitle;
  final String? initialTab;

  @override
  ConsumerState<StaffSessionContextScreen> createState() => _StaffSessionContextScreenState();
}

class _StaffSessionContextScreenState extends ConsumerState<StaffSessionContextScreen> {
  late String _tab = widget.manager &&
          const ['overview', 'attendance', 'history', 'recovery'].contains(widget.initialTab)
      ? widget.initialTab!
      : 'overview';

  void _managerTab(String value) {
    if (!const ['overview', 'attendance', 'history', 'recovery'].contains(value) || value == _tab) return;
    context.replace(Routes.managerSession(widget.sessionId, tab: value, classTitle: widget.classTitle));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final managerTabs = [
      (value: 'overview', label: t('mdy.teaching.tabOverview')),
      (value: 'attendance', label: t('mdy.teaching.attend')),
      (value: 'history', label: t('mdy.attendance.session.historyTab')),
      (value: 'recovery', label: t('mdy.attendance.session.recoveryTab')),
    ];
    final StaffDetailTabs detailTabs = (
      title: t('mdy.teaching.mentorSessionTitle'),
      tabs: managerTabs,
      tab: _tab,
      onTab: _managerTab,
    );
    void back() => staffBack(context, manager: widget.manager);
    if (widget.manager && _tab == 'history') {
      return AttendanceAuditsView(
        sessionId: widget.sessionId,
        classTitle: widget.classTitle,
        onBack: back,
        detailTabs: detailTabs,
      );
    }
    if (widget.manager && _tab == 'recovery') {
      return AttendanceRecoveryView(
        sessionId: widget.sessionId,
        classTitle: widget.classTitle,
        onBack: back,
        detailTabs: detailTabs,
        onSaved: () => context.replace(
          Routes.managerSession(widget.sessionId, tab: 'attendance', classTitle: widget.classTitle),
        ),
      );
    }
    final role = widget.manager ? TeachingRole.MANAGER : TeachingRole.MENTOR;
    final request = TeachingRequest(kind: TeachingKind.context, role: role, sessionId: widget.sessionId);
    final query = ref.watch(teachingQueryProvider(request));
    return TeachingPage(
      prefix: 'session',
      title: t('mdy.teaching.mentorSessionTitle'),
      subtitle: widget.classTitle,
      failure: fatalOf(query),
      deniedTitle: t('mdy.teaching.sessionDenied'),
      deniedBody: t('mdy.teaching.sessionDeniedBody'),
      notFound: t('mdy.teaching.sessionNotFound'),
      tabs: widget.manager
          ? managerTabs
          : [
              (value: 'overview', label: t('mdy.teaching.tabOverview')),
              (value: 'students', label: t('mdy.teaching.statStudents')),
              (value: 'materials', label: t('mdy.teaching.tabMaterials')),
            ],
      tab: _tab,
      onTab: widget.manager ? _managerTab : (v) => setState(() => _tab = v),
      onBack: back,
      onRefresh: () => ref.read(teachingQueryProvider(request).notifier).refresh(),
      children: widget.manager
          ? [
              Offstage(
                offstage: _tab != 'overview',
                child: _ManagerContext(query: query, onRetry: ref.read(teachingQueryProvider(request).notifier).refresh),
              ),
              ManagerAttendancePanel(sessionId: widget.sessionId, active: _tab == 'attendance'),
            ]
          : [
              _MentorContext(
                sessionId: widget.sessionId,
                query: query,
                tab: _tab,
                onRetry: ref.read(teachingQueryProvider(request).notifier).refresh,
              ),
            ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final MdyIcons icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(MdySpace.s10),
        child: Row(
          spacing: MdySpace.s12,
          children: [
            Container(
              width: MdySpace.s40,
              height: MdySpace.s40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.tint2, shape: BoxShape.circle),
              child: MdyIcon(icon, size: 20, color: c.link),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MdySpace.s2,
                children: [
                  Text(label, style: MdyType.size(12).copyWith(color: c.tertiary)),
                  Text(value, style: MdyType.size(14, MdyType.w500).copyWith(color: c.ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _timezoneNote(BuildContext context, String text) => differentTimezone()
    ? Text(text, style: MdyType.size(12).copyWith(color: context.mdy.secondary))
    : const SizedBox.shrink();

class _MentorContext extends ConsumerWidget {
  const _MentorContext({required this.sessionId, required this.query, required this.tab, required this.onRetry});
  final String sessionId;
  final TeachingQueryState query;
  final String tab;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final language = ref.watch(localeProvider).languageCode;
    final item = query.data?.session;
    final active = item != null && item.status != SessionStatus.CANCELLED;
    final studentsRequest = TeachingRequest(kind: TeachingKind.sessionStudents, role: TeachingRole.MENTOR, sessionId: sessionId);
    final students = active && tab == 'students' ? ref.watch(teachingQueryProvider(studentsRequest)) : null;
    final classInfo = item == null
        ? null
        : ref
              .watch(teachingQueryProvider(TeachingRequest(kind: TeachingKind.klass, role: TeachingRole.MENTOR, classId: item.classId)))
              .data
              ?.classInfo;
    return QueryBlock(
      query: query,
      prefix: 'session',
      onRetry: onRetry,
      builder: (context) {
        if (item == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MdySpace.s20,
          children: [
            Offstage(
              offstage: tab != 'overview',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MdySpace.s20,
                children: [
                  MdyCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: MdySpace.s24, vertical: MdySpace.s16),
                    gap: MdySpace.s14,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: MdySpace.s8,
                        runSpacing: MdySpace.s8,
                        children: [
                          TeachingStatusChip(group: 'mentorSessionStatus', value: item.status.name),
                          if (item.assignment == SessionAssignment.SUBSTITUTE)
                            MdyChip(t('mdy.teaching.assignment.SUBSTITUTE'), variant: MdyChipVariant.warning),
                          if (item.makeup) MdyChip(t('mdy.teaching.makeup'), variant: MdyChipVariant.info),
                          Text(item.title, style: MdyType.size(12).copyWith(color: c.tertiary)),
                        ],
                      ),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: MdySpace.s8,
                        runSpacing: MdySpace.s8,
                        children: [
                          Text(
                            '${time(item.startsAt)} – ${time(item.endsAt)}',
                            style: MdyType.size(20, MdyType.w700).copyWith(color: c.link),
                          ),
                          Text(
                            '${weekdayName(item.startsAt, language)} ${shortDate(vietnamDate(item.startsAt))}',
                            style: MdyType.size(13).copyWith(color: c.secondary),
                          ),
                        ],
                      ),
                      if (item.actualStart != null)
                        Text(
                          t('mdy.teaching.actualStart', {'time': time(item.actualStart!)}),
                          style: MdyType.size(13).copyWith(color: c.secondary),
                        ),
                      if (item.actualEnd != null)
                        Text(
                          t('mdy.teaching.actualEnd', {'time': time(item.actualEnd!)}),
                          style: MdyType.size(13).copyWith(color: c.secondary),
                        ),
                      MentorAttendanceEntry(
                        item: item,
                        studentTotal: students?.data?.total,
                        roomAction: item.status == SessionStatus.IN_PROGRESS ? _MentorRoomAction(item: item) : null,
                      ),
                    ],
                  ),
                  TeachingGroup(t('mdy.teaching.sessionInfo')),
                  MdyCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(MdySpace.s6),
                    gap: 0,
                    children: [
                      _InfoRow(
                        icon: (item.room ?? '').isNotEmpty || item.meetingUrl == null ? MdyIcons.locationOn : MdyIcons.videocam,
                        label: t('mdy.teaching.location'),
                        value: item.room ?? t(item.meetingUrl != null ? 'mdy.teaching.online' : 'mdy.teaching.roomEmpty'),
                      ),
                      _InfoRow(
                        icon: MdyIcons.person,
                        label: t('mdy.teaching.primary'),
                        value: item.assignment == SessionAssignment.PRIMARY
                            ? t('mdy.teaching.youShort')
                            : (item.primaryMentor ?? t('mdy.teaching.nameUnavailable')),
                      ),
                      if (classInfo != null)
                        _InfoRow(icon: MdyIcons.tag, label: t('mdy.teaching.classCode'), value: classInfo.code),
                      // Flutter giữ lại: bài tập code của buổi (RN chưa có).
                      MdyRow(
                        key: const Key('session-code-assignments'),
                        compact: true,
                        icon: MdyIcons.editNote,
                        label: t('mentor.code.title'),
                        subtitle: t('mentor.code.subtitle'),
                        onPress: () => context.push(Routes.mentorSessionCode(item.id)),
                      ),
                    ],
                  ),
                  _timezoneNote(context, t('mdy.teaching.timezone')),
                ],
              ),
            ),
            if (tab == 'students')
              Column(
                key: const Key('session-students-tab'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MdySpace.s20,
                children: [
                  TeachingGroup(t('mdy.teaching.studentsHead', {'count': students?.data?.total ?? 0})),
                  if (item.status == SessionStatus.SCHEDULED)
                    MdyAlert(t('mdy.teaching.provisional'), key: const Key('session-provisional'), warning: true),
                  if (students != null)
                    QueryBlock(
                      query: students,
                      prefix: 'session-students',
                      onRetry: ref.read(teachingQueryProvider(studentsRequest).notifier).refresh,
                      builder: (context) => MdyCard(
                        margin: EdgeInsets.zero,
                        padding: students.data?.total == 0
                            ? const EdgeInsets.symmetric(horizontal: MdySpace.s16, vertical: MdySpace.s8)
                            : const EdgeInsets.all(MdySpace.s6),
                        gap: 0,
                        children: [
                          for (final s in students.data?.students ?? const <TeachingStudent>[])
                            Padding(
                              key: ValueKey('${s.id}-${s.admission.name}'),
                              padding: const EdgeInsets.symmetric(horizontal: MdySpace.s10, vertical: MdySpace.s8),
                              child: Row(
                                spacing: MdySpace.s12,
                                children: [
                                  MdyAvatar(name: s.name ?? t('mdy.teaching.nameUnavailable')),
                                  Expanded(
                                    child: Text(
                                      s.name ?? t('mdy.teaching.nameUnavailable'),
                                      style: MdyType.size(14, MdyType.w500).copyWith(color: c.ink),
                                    ),
                                  ),
                                  if (s.admission == Admission.MAKEUP)
                                    MdyChip(t('mdy.teaching.makeupStudent'), variant: MdyChipVariant.info),
                                  if (item.status == SessionStatus.SCHEDULED)
                                    MdyChip(t('mdy.teaching.notMarked'), variant: MdyChipVariant.neutral),
                                ],
                              ),
                            ),
                          if (students.data?.total == 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: MdySpace.s20),
                              child: Text(
                                t('mdy.teaching.noSessionStudents'),
                                textAlign: TextAlign.center,
                                style: MdyType.size(13).copyWith(color: c.tertiary),
                              ),
                            ),
                          TeachingFooter(
                            query: students,
                            prefix: 'session-students',
                            count: students.data?.students.length ?? 0,
                            label: t('mdy.teaching.moreStudents'),
                            onMore: ref.read(teachingQueryProvider(studentsRequest).notifier).more,
                          ),
                        ],
                      ),
                    )
                  else
                    MdyCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(horizontal: MdySpace.s16, vertical: MdySpace.s8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: MdySpace.s20),
                          child: Text(
                            t('mdy.teaching.noSessionStudents'),
                            textAlign: TextAlign.center,
                            style: MdyType.size(13).copyWith(color: c.tertiary),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            if (tab == 'materials')
              Column(
                key: const Key('session-materials-tab'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MdySpace.s20,
                children: [
                  TeachingGroup(t('mdy.teaching.materialsHead')),
                  MdyCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: MdySpace.s16, vertical: MdySpace.s8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: MdySpace.s20),
                        child: Text(
                          t(item.assignment == SessionAssignment.SUBSTITUTE
                              ? 'mdy.teaching.materialsByPrimary'
                              : 'mdy.teaching.noMaterials'),
                          textAlign: TextAlign.center,
                          style: MdyType.size(13).copyWith(color: c.tertiary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _MentorRoomAction extends ConsumerWidget {
  const _MentorRoomAction({required this.item});
  final TeachingSession item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final link = safeMeetingLink(item.meetingUrl);
    if (link == null) {
      return Text(
        t(item.meetingUrl != null ? 'mdy.teaching.linkInvalid' : 'mdy.teaching.linkEmpty'),
        style: MdyType.size(13).copyWith(color: context.mdy.secondary),
      );
    }
    return MdyButton(
      key: const Key('session-enter-room'),
      size: MdyButtonSize.sm,
      variant: MdyButtonVariant.secondary,
      icon: MdyIcons.videocam,
      semanticLabel: '${t('mdy.teaching.enterRoom')}, ${link.host}',
      padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12, vertical: MdySpace.s12),
      label: t('mdy.teaching.enterRoom'),
      onPressed: () => openMeeting(ref, link.url, 'mdy.teaching.linkFailed'),
    );
  }
}

class _ManagerContext extends ConsumerWidget {
  const _ManagerContext({required this.query, required this.onRetry});
  final TeachingQueryState query;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final language = ref.watch(localeProvider).languageCode;
    final item = query.data?.session;
    return QueryBlock(
      query: query,
      prefix: 'session',
      onRetry: onRetry,
      loading: const SkeletonList(count: 2),
      builder: (context) {
        if (item == null) return const SizedBox.shrink();
        final link = safeMeetingLink(item.meetingUrl);
        final date = vietnamDate(item.startsAt);
        final today = date == vietnamDate();
        final weekday = DateTime.parse('${date}T12:00:00Z').weekday - 1;
        final ended = item.status == SessionStatus.COMPLETED || item.status == SessionStatus.CANCELLED;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MdySpace.s20,
          children: [
            SessionOperations(session: item, offline: query.offline),
            MdyCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: MdySpace.s24, vertical: MdySpace.s16),
              gap: MdySpace.s14,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: MdySpace.s12,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(vertical: MdySpace.s8),
                        decoration: BoxDecoration(
                          color: today ? c.primary : c.muted2,
                          borderRadius: BorderRadius.circular(MdyRadius.r14),
                        ),
                        child: Column(
                          spacing: MdySpace.s2,
                          children: [
                            Text(
                              weekdayLabels(language)[weekday],
                              style: MdyType.size(12).copyWith(color: today ? c.onBrand : c.secondary),
                            ),
                            Text(
                              date.substring(8),
                              style: MdyType.size(20, MdyType.w700).copyWith(color: today ? c.onBrand : c.ink),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: MdySpace.s4,
                        children: [
                          Text(item.title, style: MdyType.size(17, MdyType.w600).copyWith(color: c.ink)),
                          Semantics(
                            label: '${fullDate(item.startsAt, language)} · ${time(item.startsAt)}–${time(item.endsAt)}',
                            excludeSemantics: true,
                            child: Text(
                              '${weekdayLabels(language)[weekday]}, ${calendarDate(date)} · ${time(item.startsAt)}–${time(item.endsAt)}',
                              style: MdyType.size(13).copyWith(color: c.secondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      widthFactor: 1,
                      child: TeachingStatusChip(group: 'sessionStatus', value: item.status.name),
                    ),
                  ],
                ),
                if (item.assignment == SessionAssignment.SUBSTITUTE || item.makeup)
                  Wrap(
                    spacing: MdySpace.s8,
                    runSpacing: MdySpace.s8,
                    children: [
                      if (item.assignment == SessionAssignment.SUBSTITUTE)
                        MdyChip(t('mdy.teaching.assignment.SUBSTITUTE'), variant: MdyChipVariant.info),
                      if (item.makeup) MdyChip(t('mdy.teaching.makeup'), variant: MdyChipVariant.info),
                    ],
                  ),
                if (item.actualStart != null)
                  Text(
                    t('mdy.teaching.actualStart', {'time': time(item.actualStart!)}),
                    style: MdyType.size(13).copyWith(color: c.secondary),
                  ),
                if (item.actualEnd != null)
                  Text(
                    t('mdy.teaching.actualEnd', {'time': time(item.actualEnd!)}),
                    style: MdyType.size(13).copyWith(color: c.secondary),
                  ),
              ],
            ),
            TeachingGroup(t('mdy.teaching.sessionInfo')),
            MdyCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(MdySpace.s6),
              gap: 0,
              children: [
                if (item.effectiveMentor != null || item.status != SessionStatus.CANCELLED)
                  _InfoRow(
                    icon: MdyIcons.person,
                    label: t('mdy.teaching.effective'),
                    value: item.effectiveMentor ?? t('mdy.teaching.teacherMissing'),
                  ),
                if (!(item.assignment == SessionAssignment.PRIMARY && item.effectiveMentor != null))
                  _InfoRow(
                    icon: MdyIcons.person,
                    label: t('mdy.teaching.primary'),
                    value: item.primaryMentor ?? t('mdy.teaching.nameUnavailable'),
                  ),
                _InfoRow(
                  icon: MdyIcons.locationOn,
                  label: t('mdy.teaching.sessionRoom'),
                  value: item.room ?? t('mdy.teaching.roomEmpty'),
                ),
                if (!ended)
                  link != null
                      ? Semantics(
                          link: true,
                          label: '${t('mdy.teaching.link')}, ${link.host}',
                          hint: t('mdy.teaching.linkHint'),
                          excludeSemantics: true,
                          child: MdyPressed(
                            key: const Key('session-link'),
                            onTap: () => openMeeting(ref, link.url, 'mdy.teaching.linkFailed'),
                            builder: (context, _) => Row(
                              children: [
                                Expanded(
                                  child: _InfoRow(icon: MdyIcons.videocam, label: t('mdy.teaching.link'), value: link.host),
                                ),
                                const MdyIcon(MdyIcons.openInNew, size: 18),
                              ],
                            ),
                          ),
                        )
                      : _InfoRow(
                          icon: MdyIcons.videocam,
                          label: t('mdy.teaching.link'),
                          value: t(item.meetingUrl != null ? 'mdy.teaching.linkInvalid' : 'mdy.teaching.linkEmpty'),
                        ),
              ],
            ),
            _timezoneNote(context, t('mdy.teaching.timezone')),
          ],
        );
      },
    );
  }
}
