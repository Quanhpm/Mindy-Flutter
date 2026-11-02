import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../teaching/classes_screens.dart';
import '../teaching/session_context_screen.dart';
import '../teaching/teaching_models.dart';
import 'attendance_editor_screen.dart';
import 'attendance_logic.dart';
import 'attendance_models.dart';
import 'attendance_query.dart';
import 'attendance_widgets.dart';

String _a(String key) => 'mdy.attendance.$key';

/// Clone `AttendanceAuditsScreen.tsx` (+ dạng View trong tab Lịch sử của chi tiết buổi).
class AttendanceAuditsView extends ConsumerStatefulWidget {
  const AttendanceAuditsView({
    super.key,
    required this.sessionId,
    required this.onBack,
    this.classTitle,
    this.detailTabs,
    this.params,
  });

  final String sessionId;
  final String? classTitle;
  final VoidCallback onBack;
  final StaffDetailTabs? detailTabs;

  /// Tham số đầy đủ khi mở từ tiện ích (lọc học viên, tab Sửa/Lịch sử).
  final CorrectionParams? params;

  @override
  ConsumerState<AttendanceAuditsView> createState() => _AuditsState();
}

class _AuditsState extends ConsumerState<AttendanceAuditsView> {
  late String? _enrollmentId = widget.params?.enrollmentId;
  late String? _makeupPlacementId = widget.params?.makeupPlacementId;
  late String? _studentName = widget.params?.studentName;
  bool _invalid = false;

  AttendanceRequest get _request => AttendanceRequest(
    kind: AttendanceKind.audits,
    role: TeachingRole.MANAGER,
    sessionId: widget.sessionId,
    enrollmentId: _enrollmentId,
    makeupPlacementId: _makeupPlacementId,
  );
  AttendanceRequest get _names => AttendanceRequest(
    kind: AttendanceKind.attendance,
    role: TeachingRole.MANAGER,
    sessionId: widget.sessionId,
    pageSize: 100,
    all: true,
  );

  void _clear() => setState(() {
    _enrollmentId = null;
    _makeupPlacementId = null;
    _studentName = null;
  });

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final query = ref.watch(attendanceQueryProvider(_request));
    final controller = ref.read(attendanceQueryProvider(_request).notifier);
    final names = _studentName == null ? ref.watch(attendanceQueryProvider(_names)) : null;
    // Bộ lọc server không hợp lệ: bỏ lọc thay vì áp lên một phần trang.
    if (query.error?.code == 'ATTENDANCE_ENROLLMENT_NOT_ELIGIBLE' && _enrollmentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _clear();
        setState(() => _invalid = true);
      });
    }
    final p = widget.params;
    final utility = p == null
        ? (tabs: null, tab: null, onTab: null)
        : utilityTabs(context, t, p, 'history');
    final tabs = widget.detailTabs?.tabs ?? utility.tabs;
    final total = query.data?.total ?? 0;
    return AttendancePage(
      prefix: 'audit',
      title: widget.detailTabs?.title ?? t((p?.utilityTabs ?? false) ? _a('utility.management') : _a('audit.title')),
      tabs: tabs,
      tab: widget.detailTabs?.tab ?? utility.tab,
      onTab: widget.detailTabs?.onTab ?? utility.onTab,
      subtitle: widget.classTitle,
      onBack: widget.onBack,
      refresh: controller.refresh,
      onEnd: () {
        final d = query.data;
        if (d != null && d.audits.length < d.total && !query.busy && !query.footerError && !query.offline) {
          controller.more();
        }
      },
      children: [
        if (_enrollmentId != null)
          MdyButton(
            key: const Key('audit-filter-chip'),
            variant: MdyButtonVariant.secondary,
            label: '${_studentName ?? t(_a('nameMissing'))} ×',
            onPressed: _clear,
          ),
        if (_invalid) MdyAlert(t(_a('audit.filterInvalid')), key: const Key('audit-filter-invalid'), warning: true),
        AttendanceQueryBlock(
          query: query,
          prefix: 'audit',
          controller: controller,
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s20,
            children: [
              Text(t(_a('audit.count'), {'count': total}), style: MdyType.size(12, MdyType.w600).copyWith(color: c.ink)),
              MdyCard(
                margin: EdgeInsets.zero,
                padding: total == 0 ? const EdgeInsets.all(MdySpace.s24) : const EdgeInsets.all(MdySpace.s6),
                gap: total == 0 ? MdySpace.s12 : 0,
                children: [
                  for (final item in query.data?.audits ?? const <Audit>[])
                    _AuditRow(
                      key: ValueKey(item.id),
                      item: item,
                      name:
                          _studentName ??
                          names?.data?.rows
                              .where(
                                (r) =>
                                    r.enrollmentId == item.enrollmentId &&
                                    r.entryType == item.entryType &&
                                    r.makeupPlacementId == item.makeupPlacementId,
                              )
                              .firstOrNull
                              ?.name ??
                          (names?.data == null
                              ? (names?.error != null ? t(_a('audit.nameFailed')) : t(_a('loading')))
                              : t(_a('audit.unknownStudent'))),
                    ),
                  if (total == 0)
                    Column(
                      key: Key(_enrollmentId != null ? 'audit-empty-filter' : 'audit-empty'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: MdySpace.s12,
                      children: [
                        MdyText(
                          t(_enrollmentId != null ? _a('audit.emptyFilter') : _a('audit.empty'), {
                            'name': _studentName ?? t(_a('nameMissing')),
                          }),
                        ),
                        if (_enrollmentId != null)
                          MdyButton(variant: MdyButtonVariant.text, label: t(_a('audit.viewAll')), onPressed: _clear),
                      ],
                    ),
                ],
              ),
              if (_studentName == null && names?.error != null && !(names?.offline ?? false))
                MdyButton(
                  key: const Key('audit-names-retry'),
                  variant: MdyButtonVariant.text,
                  label: t(_a('retry')),
                  onPressed: ref.read(attendanceQueryProvider(_names).notifier).refresh,
                ),
              AttendanceMore(query: query, controller: controller, count: query.data?.audits.length ?? 0, prefix: 'audit'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Màn đứng riêng (từ tiện ích / sửa điểm danh).
class StaffAttendanceAuditsScreen extends StatelessWidget {
  const StaffAttendanceAuditsScreen({super.key, required this.params});
  final CorrectionParams params;

  @override
  Widget build(BuildContext context) => AttendanceAuditsView(
    sessionId: params.sessionId,
    classTitle: params.classTitle,
    params: params,
    onBack: () => staffBack(context, manager: true),
  );
}

class _AuditRow extends ConsumerStatefulWidget {
  const _AuditRow({super.key, required this.item, required this.name});
  final Audit item;
  final String name;

  @override
  ConsumerState<_AuditRow> createState() => _AuditRowState();
}

class _AuditRowState extends ConsumerState<_AuditRow> {
  bool _evidence = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final item = widget.item;
    final details = item.recoveryEvidence;
    String instant(DateTime? v) => v == null ? '' : '${isoTime(v)} ${isoDate(v)}';
    String status(SessionStatus s) => t(sessionStatusKey(s));
    return Container(
      key: Key('audit-row-${item.id}'),
      padding: const EdgeInsets.all(MdySpace.s12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MdySpace.s6,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: MdySpace.s8,
            runSpacing: MdySpace.s8,
            children: [
              MdyChip(
                t(_a('action.${item.action.name}')),
                variant: item.action == AuditAction.RECOVER
                    ? MdyChipVariant.info
                    : item.action == AuditAction.CORRECT
                    ? MdyChipVariant.warning
                    : MdyChipVariant.neutral,
              ),
              Text(instant(item.occurredAt), style: MdyType.size(12).copyWith(color: c.secondary)),
            ],
          ),
          Text(widget.name, style: MdyType.size(14, MdyType.w500).copyWith(color: c.ink)),
          if (item.entryType == EntryType.MAKEUP) MdyChip(t(_a('makeup')), variant: MdyChipVariant.info),
          MdyText('${item.oldStatus == null ? '' : '${t(markKey(item.oldStatus!))} → '}${t(markKey(item.newStatus))}'),
          Text(t(_a('audit.by'), {'name': item.actor ?? t(_a('nameMissing'))}), style: MdyType.size(12).copyWith(color: c.secondary)),
          if (item.reason != null) MdyText(t(_a('audit.reason'), {'reason': item.reason})),
          if (details != null) ...[
            MdyButton(
              key: Key('audit-evidence-${item.id}'),
              variant: MdyButtonVariant.text,
              label: t(_evidence ? _a('audit.evidenceClose') : _a('audit.evidenceOpen')),
              onPressed: () => setState(() => _evidence = !_evidence),
            ),
            if (_evidence)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MdySpace.s8,
                children: [
                  MdyText('${t(_a('audit.evidenceNote'))}: ${details.evidenceNote}'),
                  MdyText('${t(_a('audit.basis'))}: ${t(_a('basis.${details.admissionBasis.name}'))}'),
                  MdyText('${t(_a('audit.paidAt'))}: ${instant(details.paidAt)}'),
                  MdyText(
                    '${t(_a('audit.sessionStatus'))}: ${status(details.oldSessionStatus)} → ${status(details.newSessionStatus)}',
                  ),
                  MdyText(
                    '${t(_a('audit.actualStart'))}: '
                    '${details.oldActualStartedAt == null ? '' : '${instant(details.oldActualStartedAt)} → '}'
                    '${instant(details.newActualStartedAt)}',
                  ),
                  MdyText(
                    '${t(_a('audit.actualEnd'))}: '
                    '${details.oldActualEndedAt == null ? '' : '${instant(details.oldActualEndedAt)} → '}'
                    '${instant(details.newActualEndedAt)}',
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
