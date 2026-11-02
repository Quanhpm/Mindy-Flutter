import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/remote.dart';
import '../teaching/classes_screens.dart';
import '../teaching/teaching_models.dart';
import 'attendance_logic.dart';
import 'attendance_models.dart';
import 'attendance_query.dart';
import 'attendance_widgets.dart';

String _a(String key) => 'mdy.attendance.$key';

/// Route con của tiện ích điểm danh Quản lý (đăng ký ở router).
abstract final class StaffAttendanceRoutes {
  static const management = '/manager/attendance';
  static const studentPath = '/manager/attendance/student/:studentId';
  static String student(ManagementStudent s) => Uri(
    path: '/manager/attendance/student/${s.id}',
    queryParameters: {if (s.name != null) 'name': s.name!},
  ).toString();
  static const finalizeSessions = '/manager/attendance/finalize';
  static const finalizePath = '/manager/attendance/finalize/:sessionId';
  static String finalize(String id, {String? classTitle}) => Uri(
    path: '/manager/attendance/finalize/$id',
    queryParameters: {
      if (classTitle != null && classTitle.isNotEmpty) 'title': classTitle,
    },
  ).toString();
}

/// Clone `ManagerUtilitiesScreen.tsx` › `AttendanceManagementScreen`: chọn học viên để sửa điểm danh.
class StaffAttendanceManagementScreen extends ConsumerWidget {
  const StaffAttendanceManagementScreen({super.key});
  static const _request = AttendanceRequest(
    kind: AttendanceKind.managementStudents,
    role: TeachingRole.MANAGER,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final query = ref.watch(attendanceQueryProvider(_request));
    final controller = ref.read(attendanceQueryProvider(_request).notifier);
    return AttendancePage(
      prefix: 'attendance-students',
      title: t(_a('utility.management')),
      subtitle: t(_a('utility.chooseStudent')),
      onBack: () => staffBack(context, manager: true),
      refresh: controller.refresh,
      children: [
        AttendanceQueryBlock(
          query: query,
          prefix: 'attendance-students',
          controller: controller,
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s20,
            children: [
              MdyCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(MdySpace.s6),
                gap: 0,
                children: [
                  for (final s
                      in query.data?.managementStudents ??
                          const <ManagementStudent>[])
                    Semantics(
                      button: true,
                      child: MdyPressed(
                        key: Key('attendance-student-${s.id}'),
                        onTap: () =>
                            context.push(StaffAttendanceRoutes.student(s)),
                        builder: (context, _) => Container(
                          padding: const EdgeInsets.all(MdySpace.s12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: c.divider),
                            ),
                          ),
                          child: Row(
                            spacing: MdySpace.s12,
                            children: [
                              MdyAvatar(
                                name: s.name ?? t(_a('nameMissing')),
                                size: 36,
                              ),
                              Expanded(
                                child: Text(
                                  s.name ?? t(_a('nameMissing')),
                                  style: MdyType.size(
                                    14,
                                    MdyType.w500,
                                  ).copyWith(color: c.ink),
                                ),
                              ),
                              const MdyIcon(MdyIcons.chevronRight, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (query.data?.total == 0)
                    MdyText(
                      t(_a('utility.noStudents')),
                      key: const Key('attendance-students-empty'),
                    ),
                ],
              ),
              AttendanceMore(
                query: query,
                controller: controller,
                count: query.data?.managementStudents.length ?? 0,
                prefix: 'attendance-students',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `FormSelect`: ô chọn mở danh sách thả xuống ngay dưới ô.
class StaffFormSelect extends StatelessWidget {
  const StaffFormSelect({
    super.key,
    required this.id,
    required this.label,
    required this.placeholder,
    required this.options,
    required this.onSelect,
    this.value,
    this.disabled = false,
    this.extraBuilder,
  });

  final String id;
  final String label;
  final String placeholder;
  final String? value;
  final bool disabled;
  final List<({String id, String label})> options;
  final ValueChanged<String> onSelect;

  /// Phần cuối menu (Xem thêm / trống), dựng lại theo state hiện tại.
  final WidgetBuilder? extraBuilder;

  Future<void> _open(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final picked = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: label,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, _) {
        final mq = MediaQuery.of(dialogContext);
        final c = dialogContext.mdy;
        final width = size.width.clamp(0, mq.size.width - 32).toDouble();
        final top = origin.dy + size.height + 8;
        final below = mq.size.height - mq.padding.bottom - top - 16;
        return Stack(
          children: [
            Positioned(
              left: origin.dx.clamp(16, mq.size.width - width - 16).toDouble(),
              top: top,
              width: width,
              child: Material(
                elevation: 8,
                color: c.surface,
                shadowColor: c.ink.withValues(alpha: .14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MdyRadius.r14),
                  side: BorderSide(color: c.border),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: below.clamp(44, 320).toDouble(),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(MdySpace.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final o in options)
                          Semantics(
                            button: true,
                            child: MdyPressed(
                              key: Key('$id-option-${o.id}'),
                              onTap: () =>
                                  Navigator.of(dialogContext).pop(o.id),
                              builder: (context, _) => Container(
                                constraints: const BoxConstraints(
                                  minHeight: MdySpace.s44,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: MdySpace.s12,
                                  vertical: MdySpace.s10,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  o.label,
                                  style: MdyType.size(
                                    14,
                                  ).copyWith(color: c.ink),
                                ),
                              ),
                            ),
                          ),
                        if (extraBuilder != null)
                          Consumer(
                            builder: (context, _, _) => extraBuilder!(context),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s6,
      children: [
        Text(
          label,
          style: MdyType.size(13, MdyType.w500).copyWith(color: c.ink),
        ),
        Semantics(
          button: true,
          enabled: !disabled,
          label: '$label, ${value ?? placeholder}',
          excludeSemantics: true,
          child: Builder(
            builder: (fieldContext) => MdyPressed(
              key: Key(id),
              enabled: !disabled,
              onTap: () => _open(fieldContext),
              builder: (context, _) => Container(
                constraints: const BoxConstraints(minHeight: MdySpace.s48),
                padding: const EdgeInsets.all(MdySpace.s12),
                decoration: BoxDecoration(
                  color: disabled ? c.muted2 : c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(MdyRadius.r14),
                ),
                child: Row(
                  spacing: MdySpace.s8,
                  children: [
                    Expanded(
                      child: Text(
                        value ?? placeholder,
                        style: MdyType.size(14).copyWith(
                          color: disabled
                              ? c.tertiary
                              : (value != null ? c.ink : c.secondary),
                        ),
                      ),
                    ),
                    MdyIcon(
                      MdyIcons.expandMore,
                      size: 20,
                      color: disabled ? c.iconDisabled : c.ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _selectEmpty(BuildContext context, String key, String text) => Container(
  key: Key(key),
  constraints: const BoxConstraints(minHeight: MdySpace.s44),
  padding: const EdgeInsets.symmetric(
    horizontal: MdySpace.s12,
    vertical: MdySpace.s10,
  ),
  alignment: Alignment.centerLeft,
  child: Text(
    text,
    style: MdyType.size(14).copyWith(color: context.mdy.secondary),
  ),
);

/// Clone `StudentAttendanceFormScreen.tsx`: sửa điểm danh 1 học viên theo lớp + buổi.
class StaffStudentAttendanceFormScreen extends ConsumerStatefulWidget {
  const StaffStudentAttendanceFormScreen({
    super.key,
    required this.studentId,
    this.studentName,
  });
  final String studentId;
  final String? studentName;

  @override
  ConsumerState<StaffStudentAttendanceFormScreen> createState() =>
      _StudentFormState();
}

class _StudentFormState
    extends ConsumerState<StaffStudentAttendanceFormScreen> {
  late final AttendanceMutator _mutation = AttendanceMutator(ref, () {
    if (mounted) setState(() {});
  });
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();
  String _classId = '', _sessionId = '';
  Mark? _mark;
  int? _version;
  bool _invalid = false, _conflict = false;
  ({String kind, String id})? _pending;

  AttendanceRequest get _classes => AttendanceRequest(
    kind: AttendanceKind.classes,
    role: TeachingRole.MANAGER,
    studentId: widget.studentId,
  );
  AttendanceRequest get _sessions => AttendanceRequest(
    kind: AttendanceKind.managerSessions,
    role: TeachingRole.MANAGER,
    classId: _classId,
    mode: ManagerSessionMode.correction,
  );
  AttendanceRequest get _roster => AttendanceRequest(
    kind: AttendanceKind.attendance,
    role: TeachingRole.MANAGER,
    sessionId: _sessionId,
    pageSize: 100,
    all: true,
  );

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  void _apply(({String kind, String id}) selection) {
    setState(() {
      if (selection.kind == 'class') {
        _classId = selection.id;
        _sessionId = '';
      } else {
        _sessionId = selection.id;
      }
      _mark = null;
      _version = null;
      _reason.clear();
      _invalid = false;
      _conflict = false;
      _pending = null;
    });
    _mutation.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final classes = ref.watch(attendanceQueryProvider(_classes));
    final sessions = _classId.isEmpty
        ? null
        : ref.watch(attendanceQueryProvider(_sessions));
    final roster = _sessionId.isEmpty
        ? null
        : ref.watch(attendanceQueryProvider(_roster));
    final enrollments =
        classes.data?.managementStudents
            .where((s) => s.id == widget.studentId)
            .firstOrNull
            ?.enrollments ??
        const <StudentEnrollmentRef>[];
    final enrollment = enrollments
        .where((e) => e.classId == _classId)
        .firstOrNull;
    final row = roster?.data?.rows
        .where(
          (r) =>
              r.enrollmentId == enrollment?.enrollmentId &&
              r.makeupPlacementId == enrollment?.makeupPlacementId,
        )
        .firstOrNull;
    final session = roster?.data?.session;
    final locked = _mutation.busy || _mutation.uncertain;
    final denied =
        _mutation.result?.kind == WriteKind.denied ||
        _mutation.result?.kind == WriteKind.notFound ||
        (roster?.fatal ?? false);
    final editable =
        row != null &&
        (session?.permissions.canEditAttendance ?? false) &&
        !denied;
    final changed = _mark != null && _mark != row?.status;
    final dirty = changed || _reason.text.isNotEmpty;
    final offline = roster?.offline ?? false;
    final classOptions = [
      for (final k in classes.data?.classes ?? const <TeachingClass>[])
        if (enrollments.any((e) => e.classId == k.id))
          (id: k.id, label: k.name),
    ];
    String sessionLabel(AttendanceSession s) =>
        '${s.title} · ${isoDate(s.startsAt)} · ${isoTime(s.startsAt)}';
    final sessionOptions =
        sessions?.data?.sessions ?? const <AttendanceSession>[];
    final selectedSession = sessionOptions
        .where((s) => s.id == _sessionId)
        .firstOrNull;

    void select(String kind, String id) {
      if (locked || id == (kind == 'class' ? _classId : _sessionId)) return;
      if (dirty) {
        setState(() => _pending = (kind: kind, id: id));
      } else {
        _apply((kind: kind, id: id));
      }
    }

    Future<void> save({bool retry = false}) async {
      if (row == null ||
          session == null ||
          !editable ||
          offline ||
          _mutation.busy) {
        return;
      }
      final reason = _reason.text.trim();
      if (!retry && (!changed || reason.isEmpty || noteLength(reason) > 1000)) {
        setState(() => _invalid = true);
        _reasonFocus.requestFocus();
        return;
      }
      final result = await _mutation.submit(
        AttendanceIntent(
          key: '',
          kind: IntentKind.save,
          role: TeachingRole.MANAGER,
          sessionId: _sessionId,
          expectedVersion: _version ?? session.version,
          reason: reason,
          records: row.entryType == EntryType.REGULAR && _mark != null
              ? [(enrollmentId: row.enrollmentId, status: _mark!)]
              : const [],
          guestRecords:
              row.entryType == EntryType.MAKEUP &&
                  row.makeupPlacementId != null &&
                  _mark != null
              ? [(makeupPlacementId: row.makeupPlacementId!, status: _mark!)]
              : const [],
        ),
        retry: retry,
      );
      if (!mounted || result == null) return;
      final rosterController = ref.read(
        attendanceQueryProvider(_roster).notifier,
      );
      if (result.success) {
        setState(() {
          _mark = null;
          _version = null;
          _reason.clear();
          _invalid = false;
          _conflict = false;
        });
        ref
            .read(mdyToastProvider.notifier)
            .show(t(_a('changed'), {'count': result.changed}));
        await rosterController.refresh();
      } else if (result.kind == WriteKind.error &&
          result.code == 'SESSION_VERSION_CONFLICT') {
        setState(() {
          _mark = null;
          _version = null;
          _conflict = true;
        });
        await rosterController.refresh();
      }
    }

    Widget recordLine() {
      if (_sessionId.isEmpty) {
        return Text(
          t(_a('form.current'), {'status': '—'}),
          style: MdyType.size(13).copyWith(color: c.secondary),
        );
      }
      if (roster == null ||
          (roster.data == null && (!roster.loaded || roster.busy))) {
        return Text(
          t(_a('loading')),
          style: MdyType.size(13).copyWith(color: c.secondary),
        );
      }
      return AttendanceQueryBlock(
        query: roster,
        prefix: 'student-attendance-record',
        controller: ref.read(attendanceQueryProvider(_roster).notifier),
        builder: (_) => row == null
            ? MdyText(
                t(_a('correction.empty')),
                key: const Key('student-attendance-empty'),
              )
            : !editable
            ? MdyAlert(
                t(_a('correction.noEdit')),
                key: const Key('student-attendance-no-edit'),
                warning: true,
              )
            : Text(
                t(_a('form.current'), {'status': t(markKey(row.status))}),
                key: const Key('student-attendance-current'),
                style: MdyType.size(13).copyWith(color: c.secondary),
              ),
      );
    }

    return AttendancePage(
      prefix: 'student-attendance',
      title: t(_a('correction.title')),
      subtitle: widget.studentName ?? t(_a('nameMissing')),
      onBack: () => staffBack(context, manager: true),
      dirty: dirty,
      busy: _mutation.busy,
      uncertain: _mutation.uncertain,
      footer: [
        MdyButton(
          key: const Key('student-attendance-submit'),
          disabled: !editable || !changed || offline || locked,
          busy: _mutation.busy,
          label: t(_a('correction.submit')),
          onPressed: save,
        ),
      ],
      overlays: [
        if (_pending != null)
          MdyInlineDialog(
            title: t(_a('leaveTitle')),
            icon: MdyIcons.warning,
            onClose: () => setState(() => _pending = null),
            children: [
              MdyText(
                t(_a('leaveBody'), {'count': changed ? 1 : 0}),
                textAlign: TextAlign.center,
              ),
              MdyButton(
                label: t(_a('leaveDiscard')),
                onPressed: () => _apply(_pending!),
              ),
              MdyButton(
                variant: MdyButtonVariant.text,
                label: t(_a('leaveStay')),
                onPressed: () => setState(() => _pending = null),
              ),
            ],
          ),
      ],
      children: [
        MdyCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(MdySpace.s16),
          children: [
            StaffFormSelect(
              id: 'student-attendance-class',
              label: t(_a('form.class')),
              placeholder: classes.busy && classes.data == null
                  ? t(_a('loading'))
                  : t(_a('utility.chooseClass')),
              value: classOptions
                  .where((o) => o.id == _classId)
                  .firstOrNull
                  ?.label,
              disabled: locked,
              options: classOptions,
              onSelect: (id) => select('class', id),
              extraBuilder: (context) {
                final q = ref.watch(attendanceQueryProvider(_classes));
                return AttendanceQueryBlock(
                  query: q,
                  prefix: 'student-attendance-classes',
                  controller: ref.read(
                    attendanceQueryProvider(_classes).notifier,
                  ),
                  builder: (_) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AttendanceMore(
                        query: q,
                        controller: ref.read(
                          attendanceQueryProvider(_classes).notifier,
                        ),
                        count: q.data?.classes.length ?? 0,
                        prefix: 'student-attendance-classes',
                      ),
                      if (classOptions.isEmpty)
                        _selectEmpty(
                          context,
                          'student-attendance-no-classes',
                          t(_a('utility.noClasses')),
                        ),
                    ],
                  ),
                );
              },
            ),
            StaffFormSelect(
              key: ValueKey('session-select-$_classId'),
              id: 'student-attendance-session',
              label: t(_a('form.session')),
              placeholder: _classId.isEmpty
                  ? t(_a('form.sessionNeedsClass'))
                  : (sessions?.busy ?? false) && sessions?.data == null
                  ? t(_a('loading'))
                  : t(_a('utility.chooseSession')),
              value: selectedSession == null
                  ? null
                  : sessionLabel(selectedSession),
              disabled: _classId.isEmpty || locked,
              options: [
                for (final s in sessionOptions)
                  (id: s.id, label: sessionLabel(s)),
              ],
              onSelect: (id) => select('session', id),
              extraBuilder: _classId.isEmpty
                  ? null
                  : (context) {
                      final q = ref.watch(attendanceQueryProvider(_sessions));
                      return AttendanceQueryBlock(
                        query: q,
                        prefix: 'student-attendance-sessions',
                        controller: ref.read(
                          attendanceQueryProvider(_sessions).notifier,
                        ),
                        builder: (_) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AttendanceMore(
                              query: q,
                              controller: ref.read(
                                attendanceQueryProvider(_sessions).notifier,
                              ),
                              count: q.data?.sessions.length ?? 0,
                              prefix: 'student-attendance-sessions',
                            ),
                            if ((q.data?.sessions ?? const []).isEmpty)
                              _selectEmpty(
                                context,
                                'student-attendance-no-sessions',
                                t(_a('form.noSessions')),
                              ),
                          ],
                        ),
                      );
                    },
            ),
            ConstrainedBox(
              key: const Key('student-attendance-record'),
              constraints: const BoxConstraints(minHeight: MdySpace.s24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: recordLine(),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: MdySpace.s6,
              children: [
                Text(
                  t(_a('form.status')),
                  style: MdyType.size(13, MdyType.w500).copyWith(color: c.ink),
                ),
                Row(
                  spacing: MdySpace.s8,
                  children: [
                    for (final status in const [Mark.PRESENT, Mark.ABSENT])
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final selected = (_mark ?? row?.status) == status;
                            final disabled = !editable || locked;
                            return Opacity(
                              opacity: disabled && !selected ? .5 : 1,
                              child: MdyButton(
                                key: Key(
                                  'student-attendance-${status.name.toLowerCase()}',
                                ),
                                variant: selected
                                    ? MdyButtonVariant.primary
                                    : MdyButtonVariant.secondary,
                                disabled: disabled,
                                label: t(markKey(status)),
                                onPressed: () => setState(() {
                                  _mark = status;
                                  _version ??= session?.version;
                                  _conflict = false;
                                }),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
            AttendanceField(
              id: 'student-attendance-reason',
              label: t(_a('correction.reason')),
              controller: _reason,
              focusNode: _reasonFocus,
              onChanged: (_) => setState(() => _invalid = false),
              max: 1000,
              disabled: !editable || locked,
              error: _invalid ? t(_a('reasonRequired')) : null,
            ),
            if (_conflict)
              MdyAlert(
                t(_a('stateChanged')),
                key: const Key('student-attendance-conflict'),
                warning: true,
              ),
            MutationError(
              result: _mutation.result,
              prefix: 'student-attendance',
            ),
            if (_mutation.uncertain)
              IntentBanner(
                prefix: 'student-attendance',
                offline: offline,
                busy: _mutation.busy,
                onRetry: () => save(retry: true),
              ),
          ],
        ),
      ],
    );
  }
}

/// Clone `ManagerUtilitiesScreen.tsx` › `ManagerFinalizeSessionsScreen`: buổi đang dạy cần chốt.
class StaffFinalizeSessionsScreen extends ConsumerWidget {
  const StaffFinalizeSessionsScreen({super.key});
  static const _request = AttendanceRequest(
    kind: AttendanceKind.managerSessions,
    role: TeachingRole.MANAGER,
    mode: ManagerSessionMode.finalize,
    status: SessionStatus.IN_PROGRESS,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final query = ref.watch(attendanceQueryProvider(_request));
    final controller = ref.read(attendanceQueryProvider(_request).notifier);
    return AttendancePage(
      prefix: 'finalize-sessions',
      title: t(_a('finalize.title')),
      subtitle: t(_a('utility.chooseSession')),
      onBack: () => staffBack(context, manager: true),
      refresh: controller.refresh,
      onEnd: () {
        final d = query.data;
        if (d != null &&
            d.sessions.length < d.total &&
            !query.busy &&
            !query.offline &&
            !query.footerError) {
          controller.more();
        }
      },
      children: [
        Text(
          t(_a('utility.finalizeInfo')),
          style: MdyType.size(13).copyWith(color: c.secondary),
        ),
        AttendanceQueryBlock(
          query: query,
          prefix: 'finalize-sessions',
          controller: controller,
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s20,
            children: [
              for (final s
                  in query.data?.sessions ?? const <AttendanceSession>[])
                Semantics(
                  button: true,
                  child: MdyPressed(
                    key: Key('finalize-session-${s.id}'),
                    onTap: () => context.push(
                      StaffAttendanceRoutes.finalize(
                        s.id,
                        classTitle: s.classTitle,
                      ),
                    ),
                    builder: (context, _) => MdyCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(MdySpace.s16),
                      gap: MdySpace.s12,
                      children: [
                        Text(
                          s.classTitle,
                          style: MdyType.size(
                            15,
                            MdyType.w600,
                          ).copyWith(color: c.ink),
                        ),
                        SessionHeading(session: s),
                      ],
                    ),
                  ),
                ),
              if (query.data?.total == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: MdySpace.s24),
                  child: Text(
                    t(_a('utility.empty')),
                    key: const Key('finalize-sessions-empty'),
                    textAlign: TextAlign.center,
                    style: MdyType.text.copyWith(color: c.secondary),
                  ),
                ),
              AttendanceMore(
                query: query,
                controller: controller,
                count: query.data?.sessions.length ?? 0,
                prefix: 'finalize-sessions',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Clone `ManagerFinalizeScreen.tsx`: Quản lý chốt buổi thay Mentor (giờ kết thúc + lý do).
class StaffManagerFinalizeScreen extends ConsumerStatefulWidget {
  const StaffManagerFinalizeScreen({
    super.key,
    required this.sessionId,
    this.classTitle,
  });
  final String sessionId;
  final String? classTitle;

  @override
  ConsumerState<StaffManagerFinalizeScreen> createState() => _FinalizeState();
}

class _FinalizeState extends ConsumerState<StaffManagerFinalizeScreen> {
  late final AttendanceMutator _mutation = AttendanceMutator(ref, () {
    if (mounted) setState(() {});
  });
  final _end = TextEditingController();
  final _reason = TextEditingController();
  final _endFocus = FocusNode(), _reasonFocus = FocusNode();
  bool _endTouched = false,
      _invalid = false,
      _changed = false,
      _allowLeave = false;
  AttendanceData? _review;
  DateTime? _asOfReceived;
  DateTime? _asOf;
  late final Timer _tick;

  AttendanceRequest get _request => AttendanceRequest(
    kind: AttendanceKind.attendance,
    role: TeachingRole.MANAGER,
    sessionId: widget.sessionId,
    pageSize: 1,
  );

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    _end.dispose();
    _reason.dispose();
    _endFocus.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final query = ref.watch(attendanceQueryProvider(_request));
    final controller = ref.read(attendanceQueryProvider(_request).notifier);
    final session = query.data?.session;
    if (session != null && session.asOf != _asOf) {
      _asOf = session.asOf;
      _asOfReceived = DateTime.now();
    }
    final now = serverNow(session?.asOf, _asOfReceived ?? DateTime.now());
    final scheduledEnd = session == null ? '' : isoTime(session.endsAt);
    if (!_endTouched && _end.text != scheduledEnd) _end.text = scheduledEnd;
    if (query.data != null && _review == null) _review = query.data;
    final denied =
        query.error?.kind == RemoteFailure.denied ||
        _mutation.result?.kind == WriteKind.denied;
    final canFinalize = (session?.permissions.canFinalize ?? false) && !denied;
    final locked = _mutation.busy || _mutation.uncertain;
    final started = session?.actualStartedAt;
    final actualEndedAt = started == null
        ? null
        : parseVietnamTime(isoDate(started), _end.text);
    final endInstant = actualEndedAt == null
        ? null
        : DateTime.tryParse(actualEndedAt);
    final validTime =
        endInstant != null &&
        started != null &&
        endInstant.isAfter(started) &&
        !endInstant.isAfter(now);
    final totals = _review?.totals ?? query.data?.totals;

    Future<void> submit({bool retry = false}) async {
      final reason = _reason.text.trim();
      if (!retry &&
          (!validTime || reason.isEmpty || noteLength(reason) > 1000)) {
        setState(() => _invalid = true);
        (validTime ? _reasonFocus : _endFocus).requestFocus();
        return;
      }
      if (!retry) {
        await controller.refresh();
        final fresh = ref.read(attendanceQueryProvider(_request));
        if (fresh.error != null ||
            !(fresh.data?.session?.permissions.canFinalize ?? false)) {
          return;
        }
        if (fresh.data!.session!.version != _review?.session?.version) {
          setState(() {
            _review = fresh.data;
            _changed = true;
          });
          return;
        }
      }
      final result = await _mutation.submit(
        AttendanceIntent(
          key: '',
          kind: IntentKind.finalize,
          sessionId: widget.sessionId,
          role: TeachingRole.MANAGER,
          expectedVersion: _review?.session?.version ?? 0,
          reason: reason,
          actualEndedAt: actualEndedAt,
        ),
        retry: retry,
      );
      if (!mounted || result == null) return;
      if (result.success) {
        setState(() {
          _allowLeave = true;
          _reason.clear();
        });
        ref.read(mdyToastProvider.notifier).show(t(_a('editor.finalized')));
        if (mounted && context.mounted) staffBack(context, manager: true);
      } else if (result.kind == WriteKind.error &&
          result.code == 'SESSION_VERSION_CONFLICT') {
        await controller.refresh();
        final fresh = ref.read(attendanceQueryProvider(_request));
        if (mounted && fresh.error == null) {
          setState(() {
            _review = fresh.data;
            _changed = true;
          });
        }
      }
    }

    return AttendancePage(
      prefix: 'manager-finalize',
      title: t(_a('finalize.title')),
      subtitle: widget.classTitle ?? session?.classTitle,
      onBack: () => staffBack(context, manager: true),
      dirty:
          (_endTouched && _end.text != scheduledEnd) || _reason.text.isNotEmpty,
      busy: _mutation.busy,
      uncertain: _mutation.uncertain,
      allowLeave: _allowLeave,
      refresh: controller.refresh,
      footer: canFinalize
          ? [
              MdyButton(
                key: const Key('manager-finalize-submit'),
                disabled:
                    query.offline ||
                    locked ||
                    noteLength(_reason.text.trim()) > 1000,
                busy: _mutation.busy,
                label: t(_a('finalize.submit')),
                onPressed: submit,
              ),
            ]
          : null,
      children: [
        if (denied)
          MdyAlert(t(_a('denied')), key: const Key('manager-finalize-denied'))
        else
          AttendanceQueryBlock(
            query: query,
            prefix: 'manager-finalize',
            controller: controller,
            builder: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: MdySpace.s20,
              children: [
                if (session != null) SessionHeading(session: session),
                if (!canFinalize) ...[
                  MdyText(
                    t(_a('utility.finalizeUnavailable')),
                    key: const Key('manager-finalize-unavailable'),
                  ),
                  if (_reason.text.isNotEmpty) SelectableText(_reason.text),
                ] else ...[
                  TotalsStrip(totals: totals, prefix: 'finalize'),
                  if ((totals?.unmarked ?? 0) > 0)
                    MdyAlert(
                      t(_a('editor.finalizeImpact'), {
                        'count': totals!.unmarked,
                      }),
                      warning: true,
                    ),
                  if (_changed) MdyAlert(t(_a('changedReview')), warning: true),
                  AttendanceField(
                    id: 'finalize-end-time',
                    focusNode: _endFocus,
                    label: t(_a('finalize.end')),
                    controller: _end,
                    multiline: false,
                    keyboardType: TextInputType.datetime,
                    disabled: locked,
                    error: _invalid && !validTime ? t(_a('timeInvalid')) : null,
                    onChanged: (value) {
                      var v = value.replaceAll(RegExp(r'[^\d:]'), '');
                      v = v.replaceFirstMapped(
                        RegExp(r'^(\d{2})(\d)'),
                        (m) => '${m[1]}:${m[2]}',
                      );
                      if (v.length > 5) v = v.substring(0, 5);
                      if (v != value) {
                        _end.value = TextEditingValue(
                          text: v,
                          selection: TextSelection.collapsed(offset: v.length),
                        );
                      }
                      setState(() => _endTouched = true);
                    },
                    trailing: Semantics(
                      button: true,
                      label: t(_a('useScheduleTime')),
                      excludeSemantics: true,
                      child: MdyPressed(
                        key: const Key('finalize-use-schedule'),
                        enabled: !locked,
                        onTap: () => setState(() {
                          _endTouched = true;
                          _end.text = scheduledEnd;
                        }),
                        builder: (context, pressed) => Opacity(
                          opacity: pressed ? .7 : 1,
                          child: const SizedBox.square(
                            dimension: MdySpace.s44,
                            child: Center(
                              child: MdyIcon(MdyIcons.eventRepeat, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  AttendanceField(
                    id: 'finalize-reason',
                    focusNode: _reasonFocus,
                    label: t(_a('correction.reason')),
                    controller: _reason,
                    onChanged: (_) => setState(() {}),
                    max: 1000,
                    error: _invalid && _reason.text.trim().isEmpty
                        ? t(_a('reasonRequired'))
                        : null,
                    disabled: locked,
                  ),
                  MutationError(result: _mutation.result, prefix: 'finalize'),
                ],
                if (_mutation.uncertain)
                  IntentBanner(
                    prefix: 'finalize',
                    offline: query.offline,
                    busy: _mutation.busy,
                    onRetry: () => submit(retry: true),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Định dạng giờ HH:mm khi gõ (dùng lại ở màn khôi phục).
final hhmmFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
  var v = newValue.text.replaceAll(RegExp(r'[^\d:]'), '');
  v = v.replaceFirstMapped(RegExp(r'^(\d{2})(\d)'), (m) => '${m[1]}:${m[2]}');
  if (v.length > 5) v = v.substring(0, 5);
  return TextEditingValue(
    text: v,
    selection: TextSelection.collapsed(offset: v.length),
  );
});
