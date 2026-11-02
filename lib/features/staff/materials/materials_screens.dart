import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_widgets.dart';
import '../shared/connectivity.dart';
import '../teaching/classes_screens.dart';
import '../teaching/teaching_models.dart';
import '../teaching/teaching_query.dart';
import '../teaching/teaching_service.dart';
import '../teaching/teaching_widgets.dart';
import 'materials_query.dart';
import 'materials_service.dart';
import 'materials_widgets.dart';

abstract final class StaffMaterialRoutes {
  static const mentorDetailPath = '/mentor/materials/:classId/item/:materialId';
  static const editorPath = '/mentor/materials/:classId/editor';
  static String detail(String classId, String id) =>
      '/mentor/materials/$classId/item/$id';
  static String editor(String classId, TeachingUnit unit, {String? id}) => Uri(
    path: '/mentor/materials/$classId/editor',
    queryParameters: {
      'unitId': unit.id,
      'courseUnitId': unit.courseUnitId!,
      'title': unit.title,
      'materialId': ?id,
    },
  ).toString();
  static String preview(
    bool manager,
    String id,
    int revision, {
    String? classId,
    String? fileId,
    String? title,
  }) => Uri(
    path: '/${manager ? 'manager' : 'mentor'}/material-preview/$id',
    queryParameters: {
      'revision': '$revision',
      'classId': ?classId,
      'fileId': ?fileId,
      'title': ?title,
    },
  ).toString();
}

final materialContextProvider = FutureProvider.autoDispose
    .family<({TeachingClass? item, List<TeachingUnit> units}), String>((
      ref,
      id,
    ) async {
      ref.watch(staffOfflineProvider);
      ref.watch(materialRevisionProvider);
      ref.watch(materialRevisionProvider);
      final service = ref.watch(teachingServiceProvider),
          units = <TeachingUnit>[];
      final klass = await service.read(
        TeachingRequest(
          kind: TeachingKind.klass,
          role: TeachingRole.MENTOR,
          classId: id,
        ),
      );
      for (var page = 1; ; page++) {
        final data = await service.read(
          TeachingRequest(
            kind: TeachingKind.units,
            role: TeachingRole.MENTOR,
            classId: id,
            page: page,
            pageSize: 100,
          ),
        );
        units.addAll(data.units);
        if (units.length >= data.total) break;
        if (data.units.isEmpty) {
          throw const MaterialFailure('error', code: 'INVALID_PAGE');
        }
      }
      return (item: klass.classInfo, units: units);
    });

class StaffMaterialsScreen extends ConsumerStatefulWidget {
  const StaffMaterialsScreen({
    super.key,
    this.classId,
    this.classTitle,
    this.unitId,
    this.manager = false,
  });
  final String? classId, classTitle, unitId;
  final bool manager;
  @override
  ConsumerState<StaffMaterialsScreen> createState() => _MaterialsState();
}

class _MaterialsState extends ConsumerState<StaffMaterialsScreen> {
  String _status = 'IN_PROGRESS';
  late String _unit = widget.unitId ?? '';
  bool _picker = false;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), c = context.mdy;
    final id = widget.classId;
    if (widget.manager) {
      return AttendancePage(
        prefix: 'review-queue',
        title: t(mat('review')),
        onBack: () => staffBack(context, manager: true),
        children: [const StaffMaterialList(manager: true)],
      );
    }
    final r = TeachingRequest(
      kind: TeachingKind.classes,
      role: TeachingRole.MENTOR,
      status: _status,
    );
    final classes = id == null ? ref.watch(teachingQueryProvider(r)) : null;
    final data = id == null ? null : ref.watch(materialContextProvider(id));
    final value = data?.value;
    if (value != null && !value.units.any((u) => u.id == _unit)) {
      _unit = value.units.firstOrNull?.id ?? '';
    }
    final unit = value?.units.where((u) => u.id == _unit).firstOrNull;
    String unitLabel(TeachingUnit u) =>
        t(mat('unit'), {'position': u.position, 'title': u.title});
    return AttendancePage(
      prefix: 'materials',
      title: t(mat('title')),
      subtitle: widget.classTitle ?? t(mat('chooseClass')),
      onBack: () => staffBack(context),
      overlays: [
        if (_picker && value != null)
          MdyInlineSheet(
            key: const Key('materials-unit-sheet'),
            title: t(mat('chooseUnit')),
            onClose: () => setState(() => _picker = false),
            children: [
              for (final u in value.units)
                Semantics(
                  selected: u.id == _unit,
                  inMutuallyExclusiveGroup: true,
                  child: MdyButton(
                    key: Key('materials-unit-${u.id}'),
                    variant: u.id == _unit
                        ? MdyButtonVariant.primary
                        : MdyButtonVariant.text,
                    label: unitLabel(u),
                    onPressed: () => setState(() {
                      _unit = u.id;
                      _picker = false;
                    }),
                  ),
                ),
            ],
          ),
      ],
      children: [
        if (id == null && classes != null) ...[
          TeachingFilters(
            prefix: 'materials',
            values: const ['IN_PROGRESS', 'OPEN', 'COMPLETED'],
            value: _status,
            onChange: (v) => setState(() => _status = v),
            labelFor: (v, _) => t(mat(v)),
          ),
          QueryBlock(
            query: classes,
            prefix: 'materials',
            onRetry: ref.read(teachingQueryProvider(r).notifier).refresh,
            builder: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: MdySpace.s16,
              children: [
                for (final klass
                    in classes.data?.classes ?? const <TeachingClass>[])
                  KeyedSubtree(
                    key: Key('materials-class-${klass.id}'),
                    child: MentorClassCard(
                      item: klass,
                      onPress: () => context.push(
                        Uri(
                          path: Routes.mentorMaterials(klass.id),
                          queryParameters: {'title': klass.name},
                        ).toString(),
                      ),
                    ),
                  ),
                if (classes.data?.total == 0)
                  MdyText(
                    t(mat('noClasses')),
                    key: const Key('materials-no-classes'),
                  ),
                TeachingFooter(
                  query: classes,
                  prefix: 'materials',
                  count: classes.data?.classes.length ?? 0,
                  onMore: ref.read(teachingQueryProvider(r).notifier).more,
                ),
              ],
            ),
          ),
        ] else
          MaterialRead(
            hasData: value != null,
            busy: data?.isLoading ?? false,
            error: data?.error == null
                ? null
                : MaterialFailure.from(data!.error!),
            retry: () => ref.invalidate(materialContextProvider(id!)),
            children: [
              if (value?.item?.scope == ClassScope.SESSION)
                MdyAlert(
                  t(mat('sessionScope')),
                  warning: true,
                  key: const Key('materials-scope-alert'),
                ),
              if (value?.item?.status == ClassStatus.COMPLETED)
                MdyAlert(
                  t(mat('classEnded')),
                  warning: true,
                  key: const Key('materials-ended-alert'),
                ),
              if (unit != null) ...[
                Semantics(
                  button: true,
                  label: unitLabel(unit),
                  hint: t(mat('unitHint')),
                  child: MdyPressed(
                    key: const Key('materials-unit-picker'),
                    onTap: () => setState(() => _picker = true),
                    builder: (context, pressed) => MdyCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(MdySpace.s16),
                      children: [
                        Row(
                          spacing: MdySpace.s12,
                          children: [
                            MdyIcon(MdyIcons.menuBook, color: c.primary),
                            Expanded(child: MdyText(unitLabel(unit))),
                            const MdyIcon(MdyIcons.expandMore),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (value?.item?.authorMaterials == true &&
                    unit.courseUnitId != null)
                  MdyButton(
                    key: const Key('materials-upload'),
                    icon: MdyIcons.uploadFile,
                    label: t(mat('upload')),
                    disabled: ref.watch(staffOfflineProvider),
                    onPressed: () =>
                        context.push(StaffMaterialRoutes.editor(id!, unit)),
                  ),
                StaffMaterialList(
                  key: ValueKey(unit.id),
                  classId: id,
                  unitId: unit.id,
                  showFilters: value?.item?.scope != ClassScope.SESSION,
                ),
              ] else
                MdyText(
                  t(mat('noUnits')),
                  key: const Key('materials-no-units'),
                ),
            ],
          ),
      ],
    );
  }
}

class StaffMaterialList extends ConsumerStatefulWidget {
  const StaffMaterialList({
    super.key,
    this.manager = false,
    this.classId,
    this.unitId,
    this.showFilters = true,
  });
  final bool manager, showFilters;
  final String? classId, unitId;
  @override
  ConsumerState<StaffMaterialList> createState() => _ListState();
}

class _ListState extends ConsumerState<StaffMaterialList> {
  late String _filter = widget.manager ? 'PENDING_REVIEW' : '';
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final r = (
      manager: widget.manager,
      classId: widget.classId,
      unitId: widget.unitId,
      status: _filter,
    );
    final q = ref.watch(materialListProvider(r)),
        controller = ref.read(materialListProvider(r).notifier);
    final names = widget.manager
        ? ref.watch(materialNamesProvider).value
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s12,
      children: [
        if (widget.showFilters)
          TeachingFilters(
            prefix: 'materials',
            values: widget.manager
                ? const ['PENDING_REVIEW', 'APPROVED', 'REJECTED']
                : const ['', 'DRAFT', 'PENDING_REVIEW', 'REJECTED', 'APPROVED'],
            value: _filter,
            onChange: (v) => setState(() => _filter = v),
            labelFor: (v, _) => t(mat(v.isEmpty ? 'all' : v)),
          ),
        MaterialRead(
          hasData:
              q.page > 0 && !['denied', 'notFound'].contains(q.error?.kind),
          busy: q.busy,
          error: q.error,
          retry: controller.refresh,
          children: [
            MdyText(
              '${q.total} ${t(mat('title')).toLowerCase()}',
              key: const Key('materials-total'),
            ),
            if (q.items.isEmpty) ...[
              const Center(child: MdyCircleIcon(MdyIcons.menuBook)),
              MdyText(
                t(mat(_filter.isEmpty ? 'emptyUnit' : 'empty')),
                key: Key(
                  widget.manager || _filter.isEmpty
                      ? 'materials-empty'
                      : 'materials-empty-filter',
                ),
                textAlign: TextAlign.center,
              ),
              if (!widget.manager && _filter.isNotEmpty)
                MdyButton(
                  key: const Key('materials-clear-filter'),
                  variant: MdyButtonVariant.text,
                  label: t(mat('clear')),
                  onPressed: () => setState(() => _filter = ''),
                ),
            ],
            for (final item in q.items)
              MaterialRow(
                item: item,
                prefix: widget.manager ? 'review-queue' : 'materials',
                classTitle: names?.classes[item.classId],
                author: names?.mentors[item.createdBy],
                onTap: () => context.push(
                  widget.manager
                      ? Routes.managerMaterial(item.id)
                      : StaffMaterialRoutes.detail(widget.classId!, item.id),
                ),
              ),
            if (q.items.length < q.total)
              MdyButton(
                key: const Key('materials-more'),
                label: t(mat('more')),
                busy: q.busy,
                disabled: ref.watch(staffOfflineProvider),
                onPressed: controller.more,
              ),
            MdyButton(
              variant: MdyButtonVariant.text,
              size: MdyButtonSize.sm,
              label: t(mat('check')),
              disabled: q.busy || ref.watch(staffOfflineProvider),
              onPressed: controller.refresh,
            ),
          ],
        ),
      ],
    );
  }
}
