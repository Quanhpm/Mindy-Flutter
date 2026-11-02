import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_input.dart';
import '../../../core/ui/staff/staff_stats.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';
import '../../../core/utils/format.dart';
import '../../my_classes/my_classes_models.dart';
import '../classes/class_picker.dart';
import '../classes/classes_providers.dart';
import '../reports/reports_models.dart';
import '../reports/reports_providers.dart';
import 'student_detail_sheet.dart';
import 'student_filter_sheet.dart';
import 'students_models.dart';
import 'students_providers.dart';

class MentorStudentsScreen extends ConsumerStatefulWidget {
  const MentorStudentsScreen({super.key, this.classId});
  final String? classId;
  @override
  ConsumerState<MentorStudentsScreen> createState() => _MentorStudentsScreenState();
}

class _MentorStudentsScreenState extends ConsumerState<MentorStudentsScreen> {
  final _search = TextEditingController();
  late String? _selected = widget.classId;
  MentorStudentFilter _filter = MentorStudentFilter.all;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), classes = ref.watch(mentorPrimaryClassesProvider);
    ref.listen(sessionEpochProvider, (before, after) {
      if (before != after) {
        _search.clear();
        setState(() {
          _selected = null;
          _filter = MentorStudentFilter.all;
        });
      }
    });
    final available = classes.isLoading || classes.hasError ? null : classes.value;
    // Giữ classId từ deep link để provider kiểm tra quyền; không tự thay bằng lớp khác.
    final id = available == null || available.isEmpty ? _selected : _selected ?? available.first.id;
    final value = id == null ? null : ref.watch(mentorStudentsProvider(id));
    void retry() {
      if (id != null) {
        ref.invalidate(mentorClassAttendanceSummaryProvider(id));
        ref.invalidate(mentorPrimaryWorkspaceProvider(id));
        ref.invalidate(mentorStudentsProvider(id));
      }
    }

    return StaffPage(
      title: t('mentor.students.title'),
      subtitle: t('mentor.students.subtitle'),
      body: RefreshIndicator(
        onRefresh: () async {
          if (id == null) {
            ref.invalidate(mentorPrimaryClassesProvider);
            await ref.read(mentorPrimaryClassesProvider.future);
          } else {
            retry();
            await ref.read(mentorStudentsProvider(id).future);
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            MentorClassPicker(
              value: classes,
              selectedId: id,
              onSelected: (id) => setState(() {
                _selected = id;
                _search.clear();
                _filter = MentorStudentFilter.all;
              }),
            ),
            const SizedBox(height: 20),
            if (value != null)
              ...value.when(
                skipLoadingOnRefresh: false,
                loading: () => [const Skeleton(height: 120), const SizedBox(height: 16), const Skeleton(height: 230)],
                error: (error, _) => [
                  StaffDataState(
                    title: t('mentor.students.loadError'),
                    description: t(errorKey(error)),
                    error: error,
                    onRetry: retry,
                  ),
                ],
                data: (data) {
                  final rows = filterMentorStudents(data.rows, _search.text, _filter);
                  return [
                    Text(data.workspace.name, style: StaffText.section),
                    const SizedBox(height: 16),
                    StaffStats(
                      items: [
                        (label: t('mentor.students.registered'), value: '${data.rows.length}', tone: StatusTone.teal),
                        (
                          label: t('mentor.reports.average'),
                          value: formatPercent(
                            weightedAttendance(data.rows.map((row) => row.counts)),
                            t.locale.languageCode,
                          ),
                          tone: StatusTone.blue,
                        ),
                        (
                          label: t('mentor.students.attentionCount'),
                          value: '${data.rows.where((row) => needsAttention(row.counts.rate)).length}',
                          tone: StatusTone.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(t('mentor.students.currentScope'), style: StaffText.small),
                    const SizedBox(height: 16),
                    StaffInput(
                      label: t('mentor.students.search'),
                      controller: _search,
                      icon: Sym.search,
                      onChanged: (_) => setState(() {}),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Sym.tune),
                        label: Text(t('mentor.students.filters.${_filter.name}')),
                        onPressed: () async {
                          final selected = await showMentorStudentFilter(context, ref, data.rows, _filter);
                          if (mounted && selected != null) {
                            setState(() => _filter = selected);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (rows.isEmpty)
                      StaffDataState(
                        title: t('mentor.students.empty'),
                        description: t('mentor.students.emptyDescription'),
                      ),
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          onTap: () => showMentorStudentDetails(context, ref, data.workspace.id, row.student),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InitialsAvatar(name: row.student.name, size: 44),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(row.student.name, style: StaffText.bodyStrong),
                                        Text(
                                          t('mentor.students.presentCounts', {
                                            'present': row.counts.present,
                                            'eligible': row.counts.finalizedEligible,
                                          }),
                                          style: StaffText.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  StatusChip(formatPercent(row.counts.rate, t.locale.languageCode)),
                                  if (needsAttention(row.counts.rate))
                                    StatusChip(t('mentor.students.filters.attention'), tone: StatusTone.amber),
                                  if (row.student.enrollmentStatus == EnrollmentStatus.PENDING_PAYMENT)
                                    StatusChip(t('mentor.students.pendingPayment'), tone: StatusTone.gray),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ];
                },
              ),
          ],
        ),
      ),
    );
  }
}
