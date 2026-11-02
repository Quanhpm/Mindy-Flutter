import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';
import 'students_models.dart';

Future<MentorStudentFilter?> showMentorStudentFilter(
  BuildContext context,
  WidgetRef ref,
  List<MentorStudentRow> rows,
  MentorStudentFilter selected,
) => showStaffSheet<MentorStudentFilter>(
  context,
  title: ref.read(trProvider)('mentor.students.filterTitle'),
  builder: (_) => MentorStudentFilterContent(rows: rows, selected: selected),
);

class MentorStudentFilterContent extends ConsumerStatefulWidget {
  const MentorStudentFilterContent({super.key, required this.rows, required this.selected});
  final List<MentorStudentRow> rows;
  final MentorStudentFilter selected;
  @override
  ConsumerState<MentorStudentFilterContent> createState() => _MentorStudentFilterContentState();
}

class _MentorStudentFilterContentState extends ConsumerState<MentorStudentFilterContent> {
  late MentorStudentFilter _selected = widget.selected;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    ref.listen(sessionEpochProvider, (before, after) {
      if (before != after) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('mentor.students.threshold'), style: StaffText.caption),
        const SizedBox(height: 12),
        for (final filter in MentorStudentFilter.values)
          Semantics(
            selected: _selected == filter,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _selected == filter ? Sym.radioButtonChecked : Sym.radioButtonUnchecked,
                color: StaffColors.teal700,
              ),
              title: Text(t('mentor.students.filters.${filter.name}'), style: StaffText.body),
              trailing: Text('${filterMentorStudents(widget.rows, '', filter).length}', style: StaffText.bodyStrong),
              onTap: () => setState(() => _selected = filter),
            ),
          ),
        const SizedBox(height: 16),
        StaffButton(label: t('mentor.students.apply'), onPressed: () => Navigator.of(context).pop(_selected)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _selected = MentorStudentFilter.all),
          child: Text(t('mentor.students.reset')),
        ),
      ],
    );
  }
}
