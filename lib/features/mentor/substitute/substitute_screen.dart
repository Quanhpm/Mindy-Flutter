import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';
import '../schedule/schedule_models.dart';
import '../schedule/schedule_widgets.dart';

class MentorSubstituteScreen extends ConsumerWidget {
  const MentorSubstituteScreen({
    super.key,
    required this.value,
    required this.now,
    required this.onRefresh,
    required this.onRetry,
    required this.onRoom,
    required this.onAttendance,
    this.onTools,
    this.onBack,
  });
  final AsyncValue<TeachingSchedule> value;
  final DateTime now;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final ValueChanged<TeachingEntry> onRoom, onAttendance;
  final ValueChanged<TeachingEntry>? onTools;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return StaffPage(
      title: t('mentor.substitute.title'),
      subtitle: t('mentor.substitute.subtitle'),
      onBack: onBack,
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          children: [
            ...value.when(
              skipLoadingOnRefresh: false,
              loading: () => const <Widget>[Skeleton(height: 200), SizedBox(height: 12), Skeleton(height: 160)],
              error: (error, _) => <Widget>[
                StaffDataState(
                  title: t('mentor.schedule.loadError'),
                  description: t(errorKey(error)),
                  error: error,
                  onRetry: onRetry,
                ),
              ],
              data: (data) => data.substitutes.isEmpty
                  ? <Widget>[
                      StaffDataState(
                        title: t('mentor.substitute.empty'),
                        description: t('mentor.substitute.emptyDescription'),
                      ),
                    ]
                  : <Widget>[
                      for (final entry in data.substitutesForDisplay(now))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MentorSessionCard(
                            entry: entry,
                            now: now,
                            timeZone: data.timeZone,
                            substitutePage: true,
                            onRoom: onRoom,
                            onAttendance: onAttendance,
                            onTools: onTools,
                          ),
                        ),
                    ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Sym.info, color: StaffColors.teal600, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(t('mentor.substitute.note'), style: StaffText.caption)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
