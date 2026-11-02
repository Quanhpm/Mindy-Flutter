import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/remote.dart';
import 'class_detail_screens.dart';
import 'classes_screens.dart';
import 'teaching_format.dart';
import 'teaching_models.dart';
import 'teaching_query.dart';
import 'teaching_widgets.dart';

/// Clone `TeachingScheduleScreen.tsx`: dải tuần trong header, đổi tuần, danh sách buổi của ngày chọn.
class StaffTeachingScheduleScreen extends ConsumerStatefulWidget {
  const StaffTeachingScheduleScreen({super.key});

  @override
  ConsumerState<StaffTeachingScheduleScreen> createState() => _StaffTeachingScheduleScreenState();
}

class _StaffTeachingScheduleScreenState extends ConsumerState<StaffTeachingScheduleScreen> {
  String _selected = vietnamDate();
  final _loadedCounts = <String, int>{};

  TeachingRequest get _request => TeachingRequest(
    kind: TeachingKind.schedule,
    role: TeachingRole.MENTOR,
    from: '${_selected}T00:00:00+07:00',
    to: '${addDays(_selected, 1)}T00:00:00+07:00',
    pageSize: 100,
  );

  static const _classes = TeachingRequest(kind: TeachingKind.classes, role: TeachingRole.MENTOR, pageSize: 100);

  void _changeWeek(int days) {
    final next = addDays(_selected, days);
    final today = vietnamDate();
    setState(() => _selected = weekDates(next).contains(today) ? today : next);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final language = ref.watch(localeProvider).languageCode;
    final today = vietnamDate();
    final dates = weekDates(_selected);
    final weekOffset =
        (DateTime.parse('${dates.first}T00:00:00Z').difference(DateTime.parse('${weekDates(today).first}T00:00:00Z')).inDays / 7)
            .round();
    final query = ref.watch(teachingQueryProvider(_request));
    final classes = ref.watch(teachingQueryProvider(_classes));
    final sessions = query.data?.sessions ?? const <TeachingSession>[];
    final daily = sessions.where((s) => vietnamDate(s.startsAt) == _selected).toList();
    if (query.data != null && query.error == null) _loadedCounts[_selected] = daily.length;

    final weekNav = Row(
      children: [
        MdyButton(
          variant: MdyButtonVariant.text,
          semanticLabel: t('mdy.teaching.prevWeek'),
          padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12, vertical: MdySpace.s12),
          onPressed: () => _changeWeek(-7),
          child: MdyIcon(MdyIcons.arrowLeft, size: 28, color: c.onBrand),
        ),
        Expanded(
          child: Semantics(
            button: true,
            child: MdyPressed(
              key: const Key('schedule-this-week'),
              onTap: () => setState(() => _selected = vietnamDate()),
              builder: (context, _) => Column(
                spacing: MdySpace.s2,
                children: [
                  Text(
                    '${shortDate(dates.first)} – ${shortDate(dates.last)}',
                    style: MdyType.size(15, MdyType.w600).copyWith(color: c.onBrand),
                  ),
                  Text(
                    t(switch (weekOffset) {
                      0 => 'mdy.teaching.thisWeek',
                      -1 => 'mdy.teaching.prevWeek',
                      1 => 'mdy.teaching.nextWeek',
                      _ => 'mdy.teaching.backToThisWeek',
                    }),
                    style: MdyType.size(11, MdyType.w500).copyWith(color: c.weekDot),
                  ),
                ],
              ),
            ),
          ),
        ),
        MdyButton(
          variant: MdyButtonVariant.text,
          semanticLabel: t('mdy.teaching.nextWeek'),
          padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12, vertical: MdySpace.s12),
          onPressed: () => _changeWeek(7),
          child: MdyIcon(MdyIcons.arrowRight, size: 28, color: c.onBrand),
        ),
      ],
    );

    final strip = Padding(
      padding: const EdgeInsets.only(top: MdySpace.s12),
      child: Row(
        spacing: MdySpace.s4,
        children: [
          for (var i = 0; i < dates.length; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final date = dates[i];
                  final on = date == _selected;
                  final count = _loadedCounts[date];
                  final day = fullDate(DateTime.parse('${date}T12:00:00+07:00'), language);
                  return Semantics(
                    inMutuallyExclusiveGroup: true,
                    checked: on,
                    label: count == null ? day : t('mdy.teaching.dayLabel', {'day': day, 'count': count}),
                    excludeSemantics: true,
                    child: MdyPressed(
                      key: Key('schedule-day-$date'),
                      onTap: () => setState(() => _selected = date),
                      builder: (context, _) => Container(
                        constraints: const BoxConstraints(minHeight: MdySpace.s64),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? c.weekSelected : (date == today ? c.headerGlass : c.transparent),
                          borderRadius: BorderRadius.circular(MdyRadius.r18),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              weekdayLabels(language)[i],
                              textScaler: mdyMaxScale(context),
                              style: MdyType.size(11).copyWith(color: on ? c.weekInk : c.onBrand),
                            ),
                            Text(
                              date.substring(8),
                              textScaler: mdyMaxScale(context),
                              style: MdyType.size(17, MdyType.w600).copyWith(color: on ? c.weekInk : c.onBrand),
                            ),
                            SizedBox(
                              height: MdySpace.s4,
                              child: count != null && count > 0
                                  ? Container(
                                      width: MdySpace.s4,
                                      decoration: BoxDecoration(color: on ? c.weekInk : c.weekDot, shape: BoxShape.circle),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );

    final controller = ref.read(teachingQueryProvider(_request).notifier);
    return TeachingPage(
      prefix: 'schedule',
      title: t('mdy.teaching.schedule'),
      failure: fatalOf(query),
      onBack: () => staffBack(context),
      header: Column(children: [weekNav, strip]),
      onRefresh: () async {
        await Future.wait([controller.refresh(), ref.read(teachingQueryProvider(_classes).notifier).refresh()]);
      },
      children: [
        QueryBlock(
          query: query,
          prefix: 'schedule',
          onRetry: controller.refresh,
          loading: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s20,
            children: [
              _DayHeading(selected: _selected, loading: true),
              const SkeletonList(variant: 'schedule', count: 2),
            ],
          ),
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s20,
            children: [
              _DayHeading(selected: _selected, count: daily.length),
              for (final item in daily)
                _ScheduleCard(item: item, classes: classes),
              if (daily.isEmpty) MdyText(t('mdy.teaching.emptyDay'), key: const Key('schedule-empty')),
              if (sessions.isEmpty && !dates.contains(today))
                MdyButton(
                  key: const Key('schedule-back-today'),
                  label: t('mdy.teaching.backToday'),
                  onPressed: () => setState(() => _selected = vietnamDate()),
                ),
            ],
          ),
        ),
        if (differentTimezone())
          Text(t('mdy.teaching.timezone'), style: MdyType.size(12).copyWith(color: c.secondary)),
      ],
    );
  }
}

class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({required this.item, required this.classes});
  final TeachingSession item;
  final TeachingQueryState classes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final classInfo = classes.data?.classes.where((k) => k.id == item.classId).firstOrNull;
    final title = classInfo?.name;
    void open() => context.push(Routes.mentorSession(item.id));
    return MdyCard(
      key: Key('schedule-session-${item.id}'),
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(MdySpace.s16),
      gap: MdySpace.s14,
      children: [
        Semantics(
          button: true,
          child: MdyPressed(
            onTap: open,
            builder: (context, _) => IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MdySpace.s16,
                children: [
                  Container(
                    padding: const EdgeInsets.only(right: MdySpace.s16),
                    decoration: BoxDecoration(border: Border(right: BorderSide(color: c.divider))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: MdySpace.s4,
                      children: [
                        Text(time(item.startsAt), style: MdyType.size(20, MdyType.w700).copyWith(color: c.link)),
                        Text(time(item.endsAt), style: MdyType.size(12).copyWith(color: c.tertiary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: MdySpace.s6,
                      children: [
                        Wrap(
                          spacing: MdySpace.s6,
                          runSpacing: MdySpace.s6,
                          children: [
                            TeachingStatusChip(group: 'mentorSessionStatus', value: item.status.name),
                            if (item.assignment == SessionAssignment.SUBSTITUTE)
                              MdyChip(t('mdy.teaching.assignment.SUBSTITUTE'), variant: MdyChipVariant.warning),
                          ],
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 42),
                          child: classes.data == null && !classes.loaded
                              ? MdySkeleton(
                                  label: t('mdy.teaching.loading'),
                                  child: Text(
                                    t('mdy.teaching.classTitle'),
                                    maxLines: 2,
                                    style: MdyType.size(15, MdyType.w600),
                                  ),
                                )
                              : Text(
                                  title ?? t('mdy.teaching.classTitle'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: MdyType.size(15, MdyType.w600).copyWith(color: c.ink),
                                ),
                        ),
                        ScheduleLocation(item: item, classInfo: classInfo),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ScheduleActions(
          item: item,
          onAttend: () => ref.read(mdyToastProvider.notifier).show(t('mdy.teaching.attendLater')),
          onDetail: open,
        ),
      ],
    );
  }
}

class _DayHeading extends ConsumerWidget {
  const _DayHeading({required this.selected, this.count = 0, this.loading = false});
  final String selected;
  final int count;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final language = ref.watch(localeProvider).languageCode;
    final label = [
      '${weekdayName(DateTime.parse('${selected}T12:00:00+07:00'), language)}, ${shortDate(selected)}',
      if (selected == vietnamDate()) t('mdy.teaching.today'),
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: MdySpace.s8,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(label, style: MdyType.size(17, MdyType.w600).copyWith(color: c.ink)),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56),
          child: loading
              ? MdySkeleton(
                  label: t('mdy.teaching.loading'),
                  child: Text(t('mdy.teaching.sessionCount', {'count': 0}), style: MdyType.size(13)),
                )
              : count > 0
              ? Text(t('mdy.teaching.sessionCount', {'count': count}), style: MdyType.size(13).copyWith(color: c.secondary))
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// `ScheduleLocation`: phòng / Online / trạng thái tải ngữ cảnh buổi của ngày đang chọn.
class ScheduleLocation extends ConsumerWidget {
  const ScheduleLocation({super.key, required this.item, this.classInfo});
  final TeachingSession item;
  final TeachingClass? classInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final eligible = item.readSessionContext && item.status != SessionStatus.CANCELLED;
    final ctx = eligible
        ? ref.watch(
            teachingQueryProvider(TeachingRequest(kind: TeachingKind.context, role: TeachingRole.MENTOR, sessionId: item.id)),
          )
        : null;
    final info = ctx != null && ctx.loaded && ctx.error == null ? ctx.data?.session : null;
    final online =
        classInfo?.deliveryMode == DeliveryMode.ONLINE || (classInfo?.deliveryMode == null && info?.meetingUrl != null);
    final denied = ctx?.error?.kind == RemoteFailure.denied || ctx?.error?.kind == RemoteFailure.notFound;
    final pending = eligible && !(ctx?.loaded ?? false);
    final String? location = !eligible || denied
        ? null
        : (info?.room ?? '').isNotEmpty
        ? info!.room
        : online
        ? t('mdy.teaching.online')
        : pending
        ? t('mdy.teaching.loading')
        : ctx?.error?.kind == RemoteFailure.offline
        ? t('mdy.teaching.scheduleRoomOffline')
        : ctx?.error != null
        ? t('mdy.teaching.scheduleRoomError')
        : t('mdy.teaching.scheduleRoomEmpty');
    final row = Row(
      spacing: MdySpace.s4,
      children: [
        MdyIcon(online && (info?.room ?? '').isEmpty ? MdyIcons.videocam : MdyIcons.locationOn, size: 16),
        Expanded(
          child: Text(
            pending ? t('mdy.teaching.loading') : (location ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MdyType.size(13).copyWith(color: c.secondary),
          ),
        ),
      ],
    );
    if (pending) return MdySkeleton(label: t('mdy.teaching.loading'), child: row);
    return location == null ? const SizedBox.shrink() : row;
  }
}

/// `ScheduleActions`: Điểm danh (chỉ bật trong giờ học) + Chi tiết.
class ScheduleActions extends ConsumerStatefulWidget {
  const ScheduleActions({super.key, required this.item, required this.onAttend, required this.onDetail});
  final TeachingSession item;
  final VoidCallback onAttend;
  final VoidCallback onDetail;

  @override
  ConsumerState<ScheduleActions> createState() => _ScheduleActionsState();
}

class _ScheduleActionsState extends ConsumerState<ScheduleActions> {
  DateTime _now = DateTime.now();
  late final Timer _timer;
  late final AppLifecycleListener _life;

  void _update() {
    if (mounted) setState(() => _now = DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
    _life = AppLifecycleListener(onResume: _update);
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
    final item = widget.item;
    final canAttend =
        item.readSessionContext &&
        !_now.isBefore(item.startsAt) &&
        (item.status == SessionStatus.IN_PROGRESS || (item.status == SessionStatus.SCHEDULED && _now.isBefore(item.endsAt)));
    return Row(
      spacing: MdySpace.s8,
      children: [
        Expanded(
          child: MdyButton(
            size: MdyButtonSize.sm,
            icon: MdyIcons.factCheck,
            disabled: !canAttend,
            padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12, vertical: MdySpace.s8),
            label: t('mdy.teaching.attend'),
            onPressed: widget.onAttend,
          ),
        ),
        Expanded(
          child: MdyButton(
            size: MdyButtonSize.sm,
            variant: MdyButtonVariant.secondary,
            icon: MdyIcons.info,
            padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12, vertical: MdySpace.s8),
            label: t('mdy.teaching.detail'),
            onPressed: widget.onDetail,
          ),
        ),
      ],
    );
  }
}
