import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/utils/format.dart';
import '../schedule/schedule_providers.dart';
import '../schedule/schedule_models.dart';
import 'class_picker.dart';
import 'classes_models.dart';
import 'classes_providers.dart';

class MentorClassesScreen extends ConsumerStatefulWidget {
  const MentorClassesScreen({super.key});
  @override
  ConsumerState<MentorClassesScreen> createState() => _MentorClassesScreenState();
}

class _MentorClassesScreenState extends ConsumerState<MentorClassesScreen> {
  MentorClassGroup _group = MentorClassGroup.active;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), value = ref.watch(mentorPrimaryClassesProvider);
    final classes = value.isLoading || value.hasError ? <MentorClass>[] : value.value!;
    final filtered = classes.where((item) => mentorClassGroup(item.status) == _group).toList();
    return StaffPage(
      title: t('mentor.classes.title'),
      subtitle: t('mentor.classes.subtitle'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mentorClassOverviewProvider);
          ref.invalidate(mentorPrimaryWorkspaceProvider);
          ref.invalidate(mentorWorkspaceSessionsProvider);
          ref.invalidate(mentorPrimaryClassesProvider);
          await ref.read(mentorPrimaryClassesProvider.future);
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 24, bottom: 40),
          itemCount: 1 + (value.isLoading || value.hasError || filtered.isEmpty ? 1 : filtered.length),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: FilterChipsBar<MentorClassGroup>(
                  items: [
                    for (final group in MentorClassGroup.values)
                      (
                        group,
                        '${t('mentor.classes.groups.${group.name}')} (${classes.where((item) => mentorClassGroup(item.status) == group).length})',
                      ),
                  ],
                  selected: _group,
                  onSelected: (group) => setState(() => _group = group),
                ),
              );
            }
            Widget child;
            if (value.isLoading) {
              child = const Skeleton(height: 230);
            } else if (value.hasError) {
              child = StaffDataState(
                title: t('mentor.classes.loadError'),
                description: t(errorKey(value.error!)),
                error: value.error,
                onRetry: () => ref.invalidate(mentorPrimaryClassesProvider),
              );
            } else if (filtered.isEmpty) {
              child = StaffDataState(
                title: t('mentor.classes.empty'),
                description: t('mentor.classes.emptyDescription'),
              );
            } else {
              child = _MentorClassCard(item: filtered[index - 1]);
            }
            return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child);
          },
        ),
      ),
    );
  }
}

class _MentorClassCard extends ConsumerWidget {
  const _MentorClassCard({required this.item});
  final MentorClass item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), value = ref.watch(mentorClassOverviewProvider(item.id));
    final now = ref.watch(mentorNowProvider).value ?? ref.read(mentorClockProvider)();
    void retry() {
      ref.invalidate(mentorPrimaryWorkspaceProvider(item.id));
      ref.invalidate(mentorWorkspaceSessionsProvider(item.id));
      ref.invalidate(mentorClassOverviewProvider(item.id));
    }

    return GlassCard(
      onTap: () => context.push(Routes.mentorClassDetail(item.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(item.code, style: StaffText.eyebrow),
              StatusChip(t('mentor.classes.status.${item.status.name}'), tone: mentorClassTone(item.status)),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.name, style: StaffText.title),
          const SizedBox(height: 8),
          Text('${Dates.displayDay(item.startDate)} – ${Dates.displayDay(item.endDate)}', style: StaffText.caption),
          const SizedBox(height: 16),
          ...value.when(
            skipLoadingOnRefresh: false,
            loading: () => [const Skeleton(height: 80)],
            error: (error, _) => [
              Text(t('mentor.classes.detailsUnavailable'), style: StaffText.caption),
              TextButton(onPressed: retry, child: Text(t('common.retry'))),
            ],
            data: (data) {
              final next = data.next(now), workspace = data.workspace;
              final week = Dates.weekDays(Dates.localDay(now, workspace.timeZone)).toSet();
              final thisWeek =
                  data.sessions
                      .where(
                        (row) =>
                            row.session.status != TeachingStatus.CANCELLED &&
                            week.contains(Dates.localDay(row.session.startsAt, workspace.timeZone)),
                      )
                      .toList()
                    ..sort((a, b) => a.session.startsAt.compareTo(b.session.startsAt));
              return [
                Text(
                  t('mentor.classes.counts', {
                    'units': workspace.unitCount,
                    'sessions': workspace.sessionCount,
                    'students': data.enrollmentCount ?? '—',
                  }),
                  style: StaffText.bodyStrong,
                ),
                const SizedBox(height: 10),
                Text(t('mentor.classes.thisWeek'), style: StaffText.small),
                Text(
                  thisWeek.isEmpty
                      ? t('mentor.classes.noWeekSessions')
                      : thisWeek.map((row) => Dates.instant(row.session.startsAt, workspace.timeZone)).join(' · '),
                  style: StaffText.caption,
                ),
                const SizedBox(height: 10),
                Text(
                  next == null
                      ? t('mentor.classes.noNext')
                      : t('mentor.classes.next', {'date': Dates.instant(next.session.startsAt, workspace.timeZone)}),
                  style: StaffText.link,
                ),
                if (next != null)
                  Text(
                    !next.readContext
                        ? t('mentor.classes.contextRestricted')
                        : data.roomError != null
                        ? t('mentor.classes.roomUnavailable')
                        : data.roomKnown
                        ? (data.nextRoom ?? t('mentor.session.noRoom'))
                        : t('mentor.classes.roomUnavailable'),
                    style: StaffText.caption,
                  ),
                if (data.roomError != null) TextButton(onPressed: retry, child: Text(t('common.retry'))),
              ];
            },
          ),
          const SizedBox(height: 10),
          Text(t('mentor.classes.viewDetail'), style: StaffText.link),
        ],
      ),
    );
  }
}
