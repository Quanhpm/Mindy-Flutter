import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/remote.dart';
import 'teaching_format.dart';
import 'teaching_models.dart';
import 'teaching_query.dart';

/// Clone `teaching/components/shared.tsx` + `rows.tsx`.

String _lang(WidgetRef ref) => ref.watch(localeProvider).languageCode;

/// `TeachingPage`: header phụ (back, tiêu đề, phụ đề/skeleton, tab dạng thẻ) + panel nền bo 28,
/// kéo để làm mới, cuộn gần cuối thì gọi [onEndReached] (Footer "Xem thêm" tự tải).
class TeachingPage extends ConsumerWidget {
  const TeachingPage({
    super.key,
    required this.prefix,
    required this.title,
    required this.onBack,
    required this.children,
    this.subtitle,
    this.reserveSubtitle = false,
    this.subtitleLoading = false,
    this.header,
    this.failure,
    this.deniedTitle,
    this.deniedBody,
    this.notFound,
    this.tabs,
    this.tab,
    this.onTab,
    this.onRefresh,
    this.onEndReached,
  });

  final String prefix;
  final String title;
  final String? subtitle;
  final bool reserveSubtitle;

  /// `heading.loading`: phụ đề hiện skeleton.
  final bool subtitleLoading;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget? header;

  /// Lỗi chặn trang (`FatalProvider`): denied | notFound.
  final RemoteFailure? failure;
  final String? deniedTitle;
  final String? deniedBody;
  final String? notFound;
  final List<({String value, String label})>? tabs;
  final String? tab;
  final ValueChanged<String>? onTab;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onEndReached;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final blocked = failure == RemoteFailure.denied || failure == RemoteFailure.notFound;
    final tabbed = tabs != null && !blocked;
    final showSubtitle = reserveSubtitle || (subtitle ?? '').isNotEmpty;
    final firstTab = tabbed && tab == tabs!.first.value;
    final panel = ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(firstTab ? 0 : MdyRadius.r28),
        topRight: const Radius.circular(MdyRadius.r28),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: MdyGradient(variant: MdyGradientVariant.background, app: true)),
          Padding(
            padding: const EdgeInsets.all(MdySpace.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: MdySpace.s24,
              children: blocked
                  ? [
                      MdyCard(
                        key: Key('$prefix-${failure == RemoteFailure.denied ? 'denied' : 'not-found'}'),
                        center: true,
                        margin: EdgeInsets.zero,
                        children: [
                          MdyCircleIcon(failure == RemoteFailure.denied ? MdyIcons.lockPerson : MdyIcons.eventBusy),
                          Semantics(
                            header: true,
                            child: MdyText(
                              failure == RemoteFailure.denied
                                  ? (deniedTitle ?? t('mdy.teaching.denied'))
                                  : (notFound ?? t('mdy.teaching.notFound')),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (failure == RemoteFailure.denied)
                            MdyText(deniedBody ?? t('mdy.teaching.deniedBody'), textAlign: TextAlign.center),
                          MdyButton(
                            size: MdyButtonSize.sm,
                            padding: const EdgeInsets.symmetric(horizontal: MdySpace.s28, vertical: MdySpace.s8),
                            label: t('mdy.teaching.back'),
                            onPressed: onBack,
                          ),
                        ],
                      ),
                    ]
                  : children,
            ),
          ),
        ],
      ),
    );
    final screen = MdyScreen(
      key: Key('$prefix-screen'),
      app: true,
      onRefresh: onRefresh,
      children: [
        MdyBrandHeader(
          subpage: true,
          flush: tabbed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: MdySpace.s8,
                children: [
                  Semantics(
                    button: true,
                    label: t('mdy.teaching.back'),
                    excludeSemantics: true,
                    child: MdyPressed(
                      key: Key('$prefix-back-button'),
                      onTap: onBack,
                      builder: (context, pressed) => Container(
                        constraints: const BoxConstraints(minHeight: MdySpace.s44),
                        padding: const EdgeInsets.symmetric(horizontal: MdySpace.s20, vertical: MdySpace.s6),
                        alignment: Alignment.center,
                        child: MdyIcon(MdyIcons.arrowBack, color: c.onBrand),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            textScaler: mdyMaxScale(context),
                            style: MdyType.size(18, MdyType.w600).copyWith(color: c.onBrand),
                          ),
                        ),
                        if (showSubtitle)
                          ConstrainedBox(
                            key: Key('$prefix-subtitle-slot'),
                            constraints: const BoxConstraints(minHeight: 21),
                            child: !blocked && (subtitleLoading || (reserveSubtitle && subtitle == null))
                                ? SizedBox(
                                    width: 80,
                                    child: MdySkeleton(
                                      label: t('mdy.teaching.loading'),
                                      child: Text('000', style: MdyType.size(13).copyWith(color: c.onBrandMuted)),
                                    ),
                                  )
                                : (subtitle ?? '').isEmpty
                                ? const SizedBox.shrink()
                                : Text(
                                    subtitle!,
                                    key: Key('$prefix-count'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: MdyType.size(13).copyWith(color: c.onBrandMuted),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              ?header,
              if (tabbed)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Transform.translate(
                    offset: const Offset(-MdySpace.s16, 0),
                    child: Padding(
                      padding: const EdgeInsets.only(top: MdySpace.s12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final item in tabs!)
                            Semantics(
                              selected: item.value == tab,
                              button: true,
                              child: MdyPressed(
                                key: Key('$prefix-tab-${item.value}'),
                                onTap: () => onTab?.call(item.value),
                                builder: (context, _) {
                                  final on = item.value == tab;
                                  return Container(
                                    height: on ? MdySpace.s48 : MdySpace.s40,
                                    padding: const EdgeInsets.symmetric(horizontal: MdySpace.s22),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: on ? c.bg : c.headerGlass,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(MdyRadius.r18)),
                                    ),
                                    child: Text(
                                      item.label,
                                      textScaler: mdyMaxScale(context),
                                      style: MdyType.size(14, MdyType.w600).copyWith(color: on ? c.ink : c.onBrand),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (tabbed) panel else MdyOverlap(by: MdySpace.s28, child: panel),
      ],
    );
    if (onEndReached == null) return screen;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical && n.metrics.pixels >= n.metrics.maxScrollExtent - 120) onEndReached!();
        return false;
      },
      child: screen,
    );
  }
}

/// `SkeletonList`: hàng / thẻ lớp / thẻ lịch đang tải.
class SkeletonList extends ConsumerWidget {
  const SkeletonList({super.key, this.count = 3, this.variant = 'row'});
  final int count;

  /// `row` | `class` | `schedule`.
  final String variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    Widget bar(double h, double? w, {double r = MdyRadius.r5}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(color: c.muted, borderRadius: BorderRadius.circular(r)),
    );
    Widget frac(double h, double f) =>
        FractionallySizedBox(alignment: AlignmentDirectional.centerStart, widthFactor: f, child: bar(h, null));
    Widget item() => switch (variant) {
      'class' => Container(
        padding: const EdgeInsets.symmetric(horizontal: MdySpace.s24, vertical: MdySpace.s20),
        decoration: BoxDecoration(
          color: c.glass,
          border: Border.all(color: c.glassBorder),
          borderRadius: BorderRadius.circular(MdyRadius.r18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MdySpace.s14,
          children: [
            Row(children: [Expanded(child: frac(20, .6)), bar(20, 64)]),
            frac(14, .4),
            frac(16, .8),
            frac(16, .65),
          ],
        ),
      ),
      'schedule' => Container(
        padding: const EdgeInsets.all(MdySpace.s16),
        decoration: BoxDecoration(
          color: c.glass,
          border: Border.all(color: c.glassBorder),
          borderRadius: BorderRadius.circular(MdyRadius.r20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MdySpace.s14,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: MdySpace.s16,
              children: [
                Container(
                  width: 64,
                  padding: const EdgeInsets.only(right: MdySpace.s16),
                  decoration: BoxDecoration(border: Border(right: BorderSide(color: c.divider))),
                  child: Column(spacing: MdySpace.s8, children: [bar(26, null), bar(16, null)]),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: MdySpace.s8,
                    children: [bar(22, 80, r: MdyRadius.r12), frac(18, .9), frac(18, .65), frac(16, .75)],
                  ),
                ),
              ],
            ),
            Row(
              spacing: MdySpace.s8,
              children: [
                Expanded(child: bar(44, null, r: MdyRadius.r22)),
                Expanded(child: bar(44, null, r: MdyRadius.r22)),
              ],
            ),
          ],
        ),
      ),
      _ => bar(MdySpace.s84, null, r: MdyRadius.r18),
    };
    return MdySkeletonPulse(
      label: t('mdy.teaching.loading'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MdySpace.s20,
        children: [for (var i = 0; i < count; i++) item()],
      ),
    );
  }
}

/// Nhấp nháy 1 ↔ 0.55 cho cả khối (Animated.View của SkeletonList).
class MdySkeletonPulse extends StatefulWidget {
  const MdySkeletonPulse({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  State<MdySkeletonPulse> createState() => _MdySkeletonPulseState();
}

class _MdySkeletonPulseState extends State<MdySkeletonPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    lowerBound: .55,
    upperBound: 1,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.mdyReducedMotion) {
      _c
        ..stop()
        ..value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    child: ExcludeSemantics(child: FadeTransition(opacity: _c, child: widget.child)),
  );
}

/// `QueryBlock`: skeleton khi chưa có dữ liệu, nội dung khi có, cảnh báo + Thử lại khi lỗi.
class QueryBlock extends ConsumerWidget {
  const QueryBlock({
    super.key,
    required this.query,
    required this.prefix,
    required this.onRetry,
    required this.builder,
    this.loading,
  });

  final TeachingQueryState query;
  final String prefix;
  final VoidCallback onRetry;
  final WidgetBuilder builder;
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final error = query.error;
    if (error?.kind == RemoteFailure.unavailable) {
      return MdyText(t('mdy.teaching.noRoster'), key: Key('$prefix-unavailable'));
    }
    final offline = error?.offline ?? false;
    return Column(
      key: Key('$prefix-query-block'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s24,
      children: [
        if (query.data == null && !query.loaded)
          KeyedSubtree(key: Key('$prefix-loading'), child: loading ?? const SkeletonList(count: 1))
        else if (query.data != null)
          builder(context),
        if (error != null)
          Column(
            key: Key('$prefix-feedback'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s16,
            children: [
              MdyAlert(
                key: Key('$prefix-${query.data != null ? 'refresh-alert' : 'error'}'),
                t(offline
                        ? 'mdy.teaching.offline'
                        : query.data != null
                        ? 'mdy.teaching.refreshFailed'
                        : 'mdy.teaching.error') +
                    (error.requestId == null ? '' : ' ${t('mdy.teaching.support', {'id': error.requestId})}'),
                warning: true,
              ),
              if (!offline)
                Center(
                  child: MdyButton(
                    key: Key('$prefix-retry'),
                    variant: MdyButtonVariant.text,
                    size: MdyButtonSize.sm,
                    padding: const EdgeInsets.symmetric(horizontal: MdySpace.s28, vertical: MdySpace.s8),
                    busy: query.busy,
                    label: t('mdy.teaching.retry'),
                    onPressed: onRetry,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// `Filters`: hàng chip lọc cuộn ngang.
class TeachingFilters extends ConsumerWidget {
  const TeachingFilters({
    super.key,
    required this.prefix,
    required this.values,
    required this.value,
    required this.onChange,
    this.group = 'classStatus',
    this.labelFor,
  });

  final String prefix;
  final List<String> values;
  final String value;
  final ValueChanged<String> onChange;
  final String group;
  final String Function(String value, String label)? labelFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: MdySpace.s8,
        children: [
          for (final item in values)
            Semantics(
              inMutuallyExclusiveGroup: true,
              checked: item == value,
              child: MdyPressed(
                key: Key('$prefix-filter-${item.isEmpty ? 'all' : item}'),
                onTap: () => onChange(item),
                builder: (context, _) {
                  final on = item == value;
                  final label = item.isEmpty ? t('mdy.teaching.all') : t('mdy.teaching.$group.$item');
                  return Container(
                    constraints: const BoxConstraints(minHeight: MdySpace.s44),
                    padding: const EdgeInsets.symmetric(horizontal: MdySpace.s16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? c.primary : c.surface,
                      border: on ? null : Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(MdyRadius.r99),
                    ),
                    child: Text(
                      labelFor == null ? label : labelFor!(item, t('mdy.teaching.$group.$item')),
                      style: on
                          ? MdyType.size(13, MdyType.w600).copyWith(color: c.onBrand)
                          : MdyType.size(13).copyWith(color: c.link),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// `Footer`: Xem thêm / skeleton khi đang tải trang sau / lỗi trang sau.
class TeachingFooter extends ConsumerWidget {
  const TeachingFooter({
    super.key,
    required this.query,
    required this.prefix,
    required this.count,
    required this.onMore,
    this.label,
  });

  final TeachingQueryState query;
  final String prefix;
  final int count;
  final VoidCallback onMore;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final total = query.data?.total ?? 0;
    if (query.busy && query.data != null && count < total) {
      return MdySkeleton(
        key: Key('$prefix-footer-skeleton'),
        label: t('mdy.teaching.loading'),
        child: MdyButton(variant: MdyButtonVariant.text, label: label ?? t('mdy.teaching.more'), onPressed: null),
      );
    }
    if (query.footerOffline) {
      return MdyAlert(t('mdy.teaching.offline'), key: Key('$prefix-footer-offline'), warning: true);
    }
    if (query.footerError) {
      return Center(
        child: MdyButton(
          key: Key('$prefix-footer-retry'),
          size: MdyButtonSize.sm,
          padding: const EdgeInsets.symmetric(horizontal: MdySpace.s28, vertical: MdySpace.s8),
          label: t('mdy.teaching.retry'),
          onPressed: onMore,
        ),
      );
    }
    if (count < total) {
      return MdyButton(
        key: Key('$prefix-more'),
        variant: MdyButtonVariant.text,
        label: label ?? t('mdy.teaching.more'),
        onPressed: onMore,
      );
    }
    return const SizedBox.shrink();
  }
}

/// `Group`: nhãn nhóm 12 semibold.
class TeachingGroup extends StatelessWidget {
  const TeachingGroup(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(MdySpace.s8, MdySpace.s20, MdySpace.s8, 0),
    child: Semantics(
      header: true,
      child: Text(text, style: MdyType.size(12, MdyType.w600).copyWith(color: context.mdy.secondary)),
    ),
  );
}

/// `StatusChip` theo nhóm (classStatus, sessionStatus, enrollment, order, assignment, scope...).
class TeachingStatusChip extends ConsumerWidget {
  const TeachingStatusChip({super.key, required this.group, required this.value});
  final String group;
  final String value;

  static MdyChipVariant variantOf(String group, String value) {
    if (value == 'CANCELLED' || value == 'EXPIRED') {
      return group == 'order' && value == 'CANCELLED' ? MdyChipVariant.neutral : MdyChipVariant.danger;
    }
    if (value == 'PENDING' || value == 'PENDING_PAYMENT') return MdyChipVariant.warning;
    if (const ['ACTIVE', 'PAID', 'IN_PROGRESS'].contains(value)) return MdyChipVariant.success;
    if (const ['COMPLETED', 'DRAFT'].contains(value)) return MdyChipVariant.neutral;
    if (value == 'SUBSTITUTE' || value == 'SESSION') return MdyChipVariant.info;
    return MdyChipVariant.brand;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      MdyChip(ref.watch(trProvider)('mdy.teaching.$group.$value'), variant: variantOf(group, value));
}

String classScheduleLine(TeachingClass item, String language) {
  final days = weekdayLabels(language);
  return [for (final d in item.scheduleDays) days[d], ?item.scheduleTime].join(' · ');
}

Widget _iconLine(BuildContext context, MdyIcons icon, String text, {Widget? trailing}) => Row(
  spacing: MdySpace.s6,
  children: [
    MdyIcon(icon, size: 16),
    Expanded(child: Text(text, style: MdyType.size(13).copyWith(color: context.mdy.secondary))),
    ?trailing,
  ],
);

Widget _cardShell({required Key? key, required VoidCallback onPress, required List<Widget> children}) => MdyPressed(
  key: key,
  onTap: onPress,
  builder: (context, pressed) => Opacity(
    opacity: pressed ? .8 : 1,
    child: MdyCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: MdySpace.s24, vertical: MdySpace.s16),
      children: children,
    ),
  ),
);

Widget _titleBlock(BuildContext context, TeachingClass item, Widget chip, {bool tertiaryCode = false}) {
  final c = context.mdy;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: MdySpace.s12,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: MdySpace.s3,
          children: [
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MdyType.size(15, MdyType.w600).copyWith(
                color: item.status == ClassStatus.CANCELLED ? c.secondary : c.ink,
              ),
            ),
            Text(item.code, style: MdyType.size(12).copyWith(color: tertiaryCode ? c.tertiary : c.secondary)),
          ],
        ),
      ),
      chip,
    ],
  );
}

/// `MentorClassCard`.
class MentorClassCard extends ConsumerWidget {
  const MentorClassCard({super.key, required this.item, required this.onPress});
  final TeachingClass item;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final detail = [
      if (item.availableSeats != null && item.maxStudents != null)
        t('mdy.teaching.seats', {'available': item.availableSeats, 'max': item.maxStudents}),
      if (item.deliveryMode != null) t('mdy.teaching.delivery.${item.deliveryMode!.name}'),
    ].join(' · ');
    return Semantics(
      button: true,
      child: _cardShell(
        key: Key('mentor-class-${item.id}'),
        onPress: onPress,
        children: [
          _titleBlock(
            context,
            item,
            TeachingStatusChip(group: 'mentorClassStatus', value: item.status.name),
            tertiaryCode: true,
          ),
          if (item.scope == ClassScope.SESSION) ...[
            const TeachingStatusChip(group: 'scope', value: 'SESSION'),
            Text(
              t('mdy.teaching.primaryMentor', {'name': item.mentor ?? t('mdy.teaching.nameUnavailable')}),
              style: MdyType.size(13).copyWith(color: c.secondary),
            ),
          ],
          Column(
            spacing: MdySpace.s6,
            children: [
              _iconLine(context, MdyIcons.eventRepeat, '${calendarDate(item.startDate)} – ${calendarDate(item.endDate)}'),
              _iconLine(
                context,
                MdyIcons.groups,
                detail.isEmpty ? t('mdy.teaching.classDetailsUnavailable') : detail,
                trailing: const MdyIcon(MdyIcons.chevronRight, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `ClassCard` (Quản lý).
class ManagerClassCard extends ConsumerWidget {
  const ManagerClassCard({super.key, required this.item, required this.onPress, this.showSeats = true});
  final TeachingClass item;
  final VoidCallback onPress;
  final bool showSeats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final delivery = item.deliveryMode == null ? '—' : t('mdy.teaching.delivery.${item.deliveryMode!.name}');
    return Semantics(
      button: true,
      child: _cardShell(
        key: Key('manager-class-${item.id}'),
        onPress: onPress,
        children: [
          _titleBlock(context, item, TeachingStatusChip(group: 'classStatus', value: item.status.name)),
          _iconLine(
            context,
            MdyIcons.person,
            t('mdy.teaching.primaryMentor', {'name': item.mentor ?? t('mdy.teaching.nameUnavailable')}),
          ),
          _iconLine(
            context,
            MdyIcons.eventRepeat,
            '${calendarDate(item.startDate)} – ${calendarDate(item.endDate)} · $delivery',
          ),
          if (showSeats)
            _iconLine(
              context,
              MdyIcons.groups,
              item.availableSeats == null || item.maxStudents == null
                  ? '—'
                  : t('mdy.teaching.seats', {'available': item.availableSeats, 'max': item.maxStudents}),
              trailing: const MdyIcon(MdyIcons.chevronRight, size: 20),
            ),
        ],
      ),
    );
  }
}

Widget _dateBadge(BuildContext context, String date, String language, {required bool today, required bool mentor}) {
  final c = context.mdy;
  final tone = today ? c.onBrand : c.ink;
  final weekday = DateTime.parse('${date}T12:00:00Z').weekday - 1;
  return Container(
    width: MdySpace.s44,
    padding: const EdgeInsets.symmetric(vertical: MdySpace.s6),
    decoration: BoxDecoration(
      color: today ? c.primary : (mentor ? c.muted2 : c.muted),
      borderRadius: BorderRadius.circular(MdyRadius.r12),
    ),
    child: Column(
      children: [
        Text(
          weekdayLabels(language)[weekday],
          style: MdyType.size(11, mentor ? MdyType.w600 : MdyType.w400).copyWith(color: tone),
        ),
        Text(date.substring(8), style: MdyType.size(mentor ? 17 : 16, MdyType.w700).copyWith(color: tone)),
        Text(monthLabel(date, language), style: MdyType.size(11).copyWith(color: tone)),
      ],
    ),
  );
}

/// `MentorSessionRow`: buổi trong chi tiết lớp của Mentor.
class MentorSessionRow extends ConsumerWidget {
  const MentorSessionRow({super.key, required this.item, required this.onPress});
  final TeachingSession item;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final language = _lang(ref);
    final allowed = item.readSessionContext;
    final owner = allowed
        ? ''
        : item.effectiveMentor != null
        ? t('mdy.teaching.assigned', {'name': item.effectiveMentor})
        : item.status == SessionStatus.CANCELLED
        ? ''
        : t('mdy.teaching.teacherMissing');
    final date = vietnamDate(item.startsAt);
    final today = date == vietnamDate();
    final ended = item.status == SessionStatus.COMPLETED || item.status == SessionStatus.CANCELLED;
    return Semantics(
      button: allowed,
      child: MdyPressed(
        key: Key('mentor-session-${item.id}'),
        enabled: allowed,
        onTap: onPress,
        builder: (context, pressed) => Container(
          padding: const EdgeInsets.all(MdySpace.s10),
          decoration: BoxDecoration(
            color: pressed ? c.muted : (today ? c.tint : c.transparent),
            borderRadius: BorderRadius.circular(MdyRadius.r14),
          ),
          child: Row(
            spacing: MdySpace.s12,
            children: [
              _dateBadge(context, date, language, today: today, mentor: true),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: MdySpace.s3,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MdyType.size(14, MdyType.w600).copyWith(color: c.ink),
                    ),
                    Text(
                      ['${time(item.startsAt)}–${time(item.endsAt)}', ?item.room].join(' · '),
                      style: MdyType.size(12).copyWith(color: c.tertiary),
                    ),
                    if (item.assignment == SessionAssignment.SUBSTITUTE)
                      const TeachingStatusChip(group: 'assignment', value: 'SUBSTITUTE'),
                    if (owner.isNotEmpty) Text(owner, style: MdyType.size(12).copyWith(color: c.secondary)),
                  ],
                ),
              ),
              if (today && !ended)
                MdyChip(t('mdy.teaching.today'), variant: MdyChipVariant.success)
              else
                TeachingStatusChip(group: 'classSessionStatus', value: item.status.name),
            ],
          ),
        ),
      ),
    );
  }
}

/// `SessionRow`: buổi trong chi tiết lớp của Quản lý.
class ManagerSessionRow extends ConsumerWidget {
  const ManagerSessionRow({super.key, required this.item, required this.onPress});
  final TeachingSession item;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final language = _lang(ref);
    final date = vietnamDate(item.startsAt);
    final today = date == vietnamDate();
    final owner = item.effectiveMentor ?? (item.status == SessionStatus.CANCELLED ? '' : t('mdy.teaching.teacherMissing'));
    return Semantics(
      button: true,
      child: MdyPressed(
        key: Key('manager-session-${item.id}'),
        onTap: onPress,
        builder: (context, pressed) => Container(
          padding: const EdgeInsets.all(MdySpace.s10),
          decoration: BoxDecoration(
            color: pressed ? c.muted : c.transparent,
            borderRadius: BorderRadius.circular(MdyRadius.r14),
          ),
          child: Row(
            spacing: MdySpace.s12,
            children: [
              _dateBadge(context, date, language, today: today, mentor: false),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: MdySpace.s3,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MdyType.size(14, MdyType.w500).copyWith(color: c.ink),
                    ),
                    Text(
                      [
                        '${time(item.startsAt)}–${time(item.endsAt)}',
                        if (owner.isNotEmpty) owner,
                        if (item.assignment == SessionAssignment.SUBSTITUTE) t('mdy.teaching.assignment.SUBSTITUTE'),
                      ].join(' · '),
                      style: MdyType.size(12).copyWith(color: c.secondary),
                    ),
                  ],
                ),
              ),
              TeachingStatusChip(group: 'sessionStatus', value: item.status.name),
            ],
          ),
        ),
      ),
    );
  }
}

/// `StudentRow`: học viên trong roster lớp / buổi / chi tiết lớp Quản lý.
class TeachingStudentRow extends ConsumerWidget {
  const TeachingStudentRow({super.key, required this.item, this.session = false, this.manager = false});
  final TeachingStudent item;
  final bool session;
  final bool manager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final name = item.name ?? t('mdy.teaching.nameUnavailable');
    if (manager) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: MdySpace.s10, vertical: MdySpace.s8),
        child: Row(
          spacing: MdySpace.s12,
          children: [
            MdyAvatar(name: name, size: 36),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MdySpace.s4,
                children: [
                  Text(name, style: MdyType.size(14, MdyType.w500).copyWith(color: c.ink)),
                  if (item.studentStatus != null && item.studentStatus != StudentStatus.ACTIVE)
                    Text(
                      t(item.studentStatus == StudentStatus.SUSPENDED ? 'mdy.teaching.suspended' : 'mdy.teaching.pendingVerify'),
                      style: MdyType.size(12).copyWith(color: c.secondary),
                    ),
                ],
              ),
            ),
            TeachingStatusChip(group: 'enrollment', value: item.enrollment?.name ?? ''),
          ],
        ),
      );
    }
    final method = t('mdy.teaching.method.${item.method?.name}');
    final detail = item.order == OrderStatus.PAID && item.paidAt != null
        ? t('mdy.teaching.paidLine', {'date': calendarDate(vietnamDate(item.paidAt)), 'method': method})
        : item.order == OrderStatus.PENDING && item.expiresAt != null
        ? t('mdy.teaching.heldLine', {
            'dateTime': '${calendarDate(vietnamDate(item.expiresAt))} ${time(item.expiresAt!)}',
            'method': method,
          })
        : method;
    return Container(
      key: Key(session ? 'session-student-${item.id}' : 'students-row-${item.id}'),
      padding: const EdgeInsets.symmetric(horizontal: MdySpace.s8, vertical: MdySpace.s16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MdySpace.s16,
        children: [
          MdyAvatar(name: name),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: MdySpace.s4,
              children: [
                Text(name, style: MdyType.size(14, MdyType.w500).copyWith(color: c.ink)),
                if (session)
                  if (item.admission == Admission.MAKEUP) MdyChip(t('mdy.teaching.makeupStudent'), variant: MdyChipVariant.info)
                  else const SizedBox.shrink()
                else ...[
                  Wrap(
                    spacing: MdySpace.s8,
                    runSpacing: MdySpace.s8,
                    children: [
                      TeachingStatusChip(group: 'enrollment', value: item.enrollment?.name ?? ''),
                      TeachingStatusChip(group: 'order', value: item.order?.name ?? ''),
                    ],
                  ),
                  Text(detail, style: MdyType.size(12).copyWith(color: c.secondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
