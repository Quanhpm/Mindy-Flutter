import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/remote.dart';
import '../teaching/teaching_format.dart';
import '../teaching/teaching_models.dart';
import '../teaching/teaching_query.dart';

/// Clone `auth/components/TodayCard.tsx` (phần Mentor): buổi dạy hôm nay + Vào học / Điểm danh.
class MentorTodayCard extends ConsumerStatefulWidget {
  const MentorTodayCard({super.key});

  static TeachingRequest scheduleRequest(String date) => TeachingRequest(
    kind: TeachingKind.schedule,
    role: TeachingRole.MENTOR,
    from: '${date}T00:00:00+07:00',
    to: '${addDays(date, 1)}T00:00:00+07:00',
    pageSize: 100,
  );

  static const classesRequest = TeachingRequest(kind: TeachingKind.classes, role: TeachingRole.MENTOR, pageSize: 100);

  static TeachingRequest contextRequest(String sessionId) =>
      TeachingRequest(kind: TeachingKind.context, role: TeachingRole.MENTOR, sessionId: sessionId);

  @override
  ConsumerState<MentorTodayCard> createState() => _MentorTodayCardState();
}

class _MentorTodayCardState extends ConsumerState<MentorTodayCard> {
  // `useToday`: kiểm tra ngày mỗi 30 giây và khi app quay lại foreground.
  String _date = vietnamDate();
  late final Timer _timer;
  late final AppLifecycleListener _life;

  void _check() {
    final now = vietnamDate();
    if (now != _date && mounted) setState(() => _date = now);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    _life = AppLifecycleListener(onResume: _check);
  }

  @override
  void dispose() {
    _timer.cancel();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final query = ref.watch(teachingQueryProvider(MentorTodayCard.scheduleRequest(_date)));
    final item = selectTodaySession(query.data?.sessions ?? const [], _date);
    final classes = item == null ? null : ref.watch(teachingQueryProvider(MentorTodayCard.classesRequest));
    final context0 = item == null || item.status == SessionStatus.COMPLETED
        ? null
        : ref.watch(teachingQueryProvider(MentorTodayCard.contextRequest(item.id)));
    final errors = [query.error, classes?.error, context0?.error].whereType<RemoteError>();
    final offline = errors.any((e) => e.kind == RemoteFailure.offline);
    final failed = errors.any((e) => e.kind == RemoteFailure.error || e.kind == RemoteFailure.unavailable);
    if (offline || failed) {
      return _TodayFrame(
        children: [
          MdyAlert(
            key: Key(offline ? 'workspace-today-offline' : 'workspace-today-error'),
            t(offline ? 'mdy.teaching.offline' : 'mdy.teaching.home.todayFailed'),
            warning: true,
          ),
        ],
      );
    }
    final c = context.mdy;
    Widget content;
    final denied = query.error?.kind == RemoteFailure.denied || query.error?.kind == RemoteFailure.notFound;
    if (denied) {
      content = Padding(
        padding: const EdgeInsets.only(right: 80),
        child: Text(t('mdy.teaching.home.todayDenied'), style: MdyType.size(13).copyWith(color: c.ink)),
      );
    } else if (query.data == null) {
      content = query.loaded
          ? MdyAlert(
              key: const Key('workspace-today-error'),
              t(query.offline ? 'mdy.teaching.offline' : 'mdy.teaching.home.todayFailed'),
              warning: true,
            )
          : MdySkeleton(label: t('mdy.teaching.loading'), child: const _Rest());
    } else {
      content = item == null
          ? const _Rest()
          : _TodaySession(key: ValueKey('$_date-${item.id}'), item: item, classes: classes, context: context0);
    }
    return _TodayFrame(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(padding: const EdgeInsets.only(top: MdySpace.s8), child: content),
            Positioned(
              top: -MdySpace.s8,
              right: 0,
              child: Semantics(
                button: true,
                label: t('mdy.teaching.home.viewSchedule'),
                excludeSemantics: true,
                child: MdyPressed(
                  key: const Key('workspace-today-schedule'),
                  onTap: () => context.push(Routes.mentorPage('schedule')),
                  builder: (context, pressed) => ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: MdySpace.s28),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: MdySpace.s4,
                      children: [
                        Text(
                          t('mdy.teaching.home.viewSchedule'),
                          style: MdyType.size(12, MdyType.w600).copyWith(color: c.link),
                        ),
                        const MdyIcon(MdyIcons.chevronRight, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// `TodayFrame`: Card kính mờ sát lề, padding 24, gap 20.
class _TodayFrame extends StatelessWidget {
  const _TodayFrame({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MdyCard(
    key: const Key('workspace-today-card'),
    frosted: true,
    margin: EdgeInsets.zero,
    padding: const EdgeInsets.all(MdySpace.s24),
    gap: MdySpace.s20,
    children: children,
  );
}

/// `Rest`: không có buổi hôm nay.
class _Rest extends ConsumerWidget {
  const _Rest();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    return Padding(
      padding: const EdgeInsets.all(MdySpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MdySpace.s4,
        children: [
          Semantics(
            header: true,
            child: Text(
              t('mdy.teaching.home.restTitle'),
              textAlign: TextAlign.center,
              style: MdyType.size(15, MdyType.w600).copyWith(color: c.ink),
            ),
          ),
          Text(
            t('mdy.teaching.home.restBody'),
            textAlign: TextAlign.center,
            style: MdyType.size(13).copyWith(color: c.secondary),
          ),
        ],
      ),
    );
  }
}

class _TodaySession extends ConsumerWidget {
  const _TodaySession({super.key, required this.item, required this.classes, required this.context});
  final TeachingSession item;
  final TeachingQueryState? classes;

  /// `context` query (null khi buổi đã hoàn tất).
  final TeachingQueryState? context;

  @override
  Widget build(BuildContext buildContext, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = buildContext.mdy;
    final active = item.status != SessionStatus.COMPLETED;
    final title = classes?.data?.classes.where((k) => k.id == item.classId).firstOrNull?.name ?? item.title;
    final ctx = context;
    final info = ctx == null || ctx.fatal ? null : ctx.data?.session;
    final link = safeMeetingLink(info?.meetingUrl);
    final status = t(
      item.status == SessionStatus.SCHEDULED ? 'mdy.teaching.today' : 'mdy.teaching.sessionStatus.${item.status.name}',
    );
    final substitute = item.assignment == SessionAssignment.SUBSTITUTE && active;
    final contextLoading = active && ctx != null && !ctx.loaded;
    final showActions =
        active && (item.status == SessionStatus.IN_PROGRESS || contextLoading || link != null || info?.meetingUrl != null);
    void openSession() => buildContext.push(Routes.mentorSession(item.id));

    Future<void> meet(String url) async {
      try {
        final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!ok) throw StateError('launch');
      } catch (_) {
        ref.read(mdyToastProvider.notifier).show(t('mdy.teaching.linkFailed'));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s20,
      children: [
        Semantics(
          button: true,
          child: MdyPressed(
            key: const Key('workspace-today-session'),
            onTap: openSession,
            builder: (_, _) => IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MdySpace.s16,
                children: [
                  Container(
                    padding: const EdgeInsets.only(right: MdySpace.s16),
                    decoration: BoxDecoration(border: Border(right: BorderSide(color: c.divider))),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: MdySpace.s6,
                      children: [
                        Text(time(item.startsAt), style: MdyType.size(26, MdyType.w700).copyWith(color: c.link)),
                        Text(
                          t('mdy.teaching.home.until', {'time': time(item.endsAt)}),
                          style: MdyType.size(13).copyWith(color: c.secondary),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: MdySpace.s6,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: MdySpace.s64),
                          child: Semantics(
                            label: substitute ? t('mdy.teaching.home.substituteLabel', {'status': status}) : status,
                            excludeSemantics: true,
                            child: MdyChip(
                              substitute ? '⇄ $status' : status,
                              variant: item.status == SessionStatus.COMPLETED
                                  ? MdyChipVariant.neutral
                                  : substitute && item.status == SessionStatus.SCHEDULED
                                  ? MdyChipVariant.warning
                                  : MdyChipVariant.success,
                            ),
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MdyType.size(15, MdyType.w600).copyWith(color: c.ink),
                        ),
                        if ((info?.room ?? '').isNotEmpty)
                          Row(
                            spacing: MdySpace.s4,
                            children: [
                              const MdyIcon(MdyIcons.locationOn, size: 16),
                              Expanded(
                                child: Text(info!.room!, style: MdyType.size(13).copyWith(color: c.secondary)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showActions)
          Row(
            key: const Key('workspace-today-actions'),
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: MdySpace.s8,
            children: [
              if (item.status == SessionStatus.IN_PROGRESS)
                Expanded(
                  child: MdyButton(
                    key: const Key('workspace-today-attend'),
                    variant: MdyButtonVariant.secondary,
                    size: MdyButtonSize.sm,
                    padding: const EdgeInsets.symmetric(horizontal: MdySpace.s8, vertical: MdySpace.s12),
                    label: t('mdy.attendance.context.attend'),
                    onPressed: () => buildContext.push(Routes.mentorAttendance(item.id)),
                  ),
                ),
              if (contextLoading)
                Expanded(
                  child: MdySkeleton(
                    label: t('mdy.teaching.loading'),
                    child: MdyButton(
                      size: MdyButtonSize.sm,
                      icon: MdyIcons.videocam,
                      label: t('mdy.teaching.home.joinClass'),
                      onPressed: null,
                    ),
                  ),
                ),
              if (link != null)
                Expanded(
                  child: MdyButton(
                    key: const Key('workspace-today-meet'),
                    size: MdyButtonSize.sm,
                    icon: MdyIcons.videocam,
                    padding: const EdgeInsets.symmetric(horizontal: MdySpace.s8, vertical: MdySpace.s12),
                    label: t('mdy.teaching.home.joinClass'),
                    onPressed: () => meet(link.url),
                  ),
                )
              else if (info?.meetingUrl != null)
                Expanded(
                  child: Text(t('mdy.teaching.linkInvalid'), style: MdyType.size(12).copyWith(color: c.secondary)),
                ),
            ],
          ),
      ],
    );
  }
}
