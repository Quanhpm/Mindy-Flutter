import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/remote.dart';
import 'teaching_models.dart';
import 'teaching_query.dart';
import 'teaching_widgets.dart';

/// Quay lại màn trước, mở trực tiếp thì về Home của role.
void staffBack(BuildContext context, {bool manager = false}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(manager ? Routes.manager : Routes.mentor);
  }
}

const _managerFilters = ['IN_PROGRESS', 'OPEN', 'COMPLETED', 'CANCELLED', 'DRAFT'];
const _mentorFilters = ['IN_PROGRESS', 'OPEN', 'COMPLETED', 'CANCELLED'];

/// Clone `ClassesScreens.tsx` › `MentorClassesScreen` + `ManagerClassesScreen`.
class StaffClassesScreen extends ConsumerStatefulWidget {
  const StaffClassesScreen({super.key, required this.manager});
  final bool manager;

  @override
  ConsumerState<StaffClassesScreen> createState() => _StaffClassesScreenState();
}

class _StaffClassesScreenState extends ConsumerState<StaffClassesScreen> {
  String _status = 'IN_PROGRESS';
  final _search = TextEditingController();
  String _q = '';
  Timer? _debounce;
  final _counts = <String, int>{};

  bool get _manager => widget.manager;
  TeachingRole get _role => _manager ? TeachingRole.MANAGER : TeachingRole.MENTOR;
  String get _prefix => _manager ? 'manager-classes' : 'classes';

  TeachingRequest get _request => TeachingRequest(
    kind: TeachingKind.classes,
    role: _role,
    status: _status,
    q: _manager ? _q : null,
  );

  TeachingRequest get _summary => TeachingRequest(kind: TeachingKind.classes, role: _role, status: _status, pageSize: 1);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _q = value.trim());
    });
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _q = '');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final query = ref.watch(teachingQueryProvider(_request));
    final summary = ref.watch(teachingQueryProvider(_summary));
    final data = query.data;
    // Kết quả tìm kiếm không được ghi đè tổng theo trạng thái.
    if (data != null && query.error == null && (!_manager || _q.isEmpty)) _counts[_status] = data.total;
    final controller = ref.read(teachingQueryProvider(_request).notifier);
    final fatal = query.fatal && query.error!.kind != RemoteFailure.unavailable ? query.error!.kind : null;
    return TeachingPage(
      prefix: _prefix,
      reserveSubtitle: true,
      title: t(_manager ? 'mdy.teaching.managerListTitle' : 'mdy.teaching.myClasses'),
      subtitle: summary.data == null ? null : t('mdy.teaching.count', {'count': summary.data!.total}),
      subtitleLoading: summary.data == null && !summary.loaded,
      failure: fatal,
      onBack: () => staffBack(context, manager: _manager),
      onRefresh: () async {
        await Future.wait([controller.refresh(), ref.read(teachingQueryProvider(_summary).notifier).refresh()]);
      },
      onEndReached: () {
        if (!query.busy && !query.footerError && query.hasMore) controller.more();
      },
      children: [
        if (_manager)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12),
            decoration: BoxDecoration(
              color: c.glass,
              border: Border.all(color: c.glassBorder),
              borderRadius: BorderRadius.circular(MdyRadius.r99),
            ),
            child: Row(
              children: [
                const MdyIcon(MdyIcons.search, size: 18),
                Expanded(
                  child: Semantics(
                    label: t('mdy.teaching.searchLabel'),
                    child: TextField(
                      key: Key('$_prefix-search'),
                      controller: _search,
                      maxLength: 100,
                      onChanged: _onSearch,
                      style: MdyType.size(14).copyWith(color: c.ink),
                      cursorColor: c.primary,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        counterText: '',
                        constraints: const BoxConstraints(minHeight: MdySpace.s52),
                        contentPadding: const EdgeInsets.symmetric(horizontal: MdySpace.s8, vertical: MdySpace.s16),
                        hintText: t('mdy.teaching.search'),
                        hintStyle: MdyType.size(14).copyWith(color: c.secondary),
                      ),
                    ),
                  ),
                ),
                if (_search.text.isNotEmpty)
                  Semantics(
                    button: true,
                    label: t('mdy.teaching.clearSearch'),
                    excludeSemantics: true,
                    child: MdyPressed(
                      key: Key('$_prefix-clear-search'),
                      onTap: _reset,
                      builder: (context, _) => const SizedBox.square(
                        dimension: MdySpace.s44,
                        child: Center(child: MdyIcon(MdyIcons.close)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        TeachingFilters(
          prefix: _prefix,
          group: _manager ? 'classStatus' : 'mentorClassStatus',
          values: _manager ? _managerFilters : _mentorFilters,
          value: _status,
          onChange: (v) => setState(() => _status = v),
          labelFor: (value, label) => _counts[value] == null ? label : '$label (${_counts[value]})',
        ),
        QueryBlock(
          query: query,
          prefix: _prefix,
          onRetry: controller.refresh,
          loading: const SkeletonList(variant: 'class'),
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s20,
            children: [
              for (final item in data?.classes ?? const <TeachingClass>[])
                _manager
                    ? ManagerClassCard(item: item, onPress: () => context.push(Routes.managerClass(item.id)))
                    : MentorClassCard(item: item, onPress: () => context.push(Routes.mentorClassDetail(item.id))),
              if (data == null || data.total == 0)
                Padding(
                  key: Key('$_prefix-empty'),
                  padding: const EdgeInsets.symmetric(vertical: MdySpace.s32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: MdySpace.s12,
                    children: [
                      MdyText(
                        t(!_manager ? 'mdy.teaching.emptyFilter' : (_q.isNotEmpty ? 'mdy.teaching.noResults' : 'mdy.teaching.emptyManager')),
                      ),
                      if (_manager && _q.isNotEmpty)
                        MdyButton(variant: MdyButtonVariant.text, label: t('mdy.teaching.clearAll'), onPressed: _reset),
                    ],
                  ),
                ),
              TeachingFooter(
                query: query,
                prefix: _prefix,
                count: data?.classes.length ?? 0,
                onMore: controller.more,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
