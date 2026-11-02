import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../i18n/i18n.dart';
import '../../router/routes.dart';
import '../session_sheet_guard.dart';
import 'staff_theme.dart';
import 'staff_widgets.dart';

mixin OperationsBack<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool get hasDraft;
  String get fallback => Routes.mentorPage('schedule');
  bool _allowPop = false, _asking = false;
  Widget protect(Widget child) => PopScope(
    canPop: _allowPop || !hasDraft,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) back();
    },
    child: child,
  );
  void exit() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallback);
        }
      }
    });
  }

  Future<void> back() async {
    if (_asking) return;
    if (!hasDraft) {
      exit();
      return;
    }
    _asking = true;
    final t = ref.read(trProvider);
    final discard = await showStaffSheet<bool>(
      context,
      title: t('mentor.operations.leaveTitle'),
      builder: (sheet) => SessionSheetGuard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('mentor.operations.leaveDescription'), style: StaffText.body),
            const SizedBox(height: 16),
            StaffButton(label: t('mentor.operations.stay'), onPressed: () => Navigator.pop(sheet, false)),
            const SizedBox(height: 8),
            StaffButton(
              label: t('mentor.operations.leave'),
              outlined: true,
              onPressed: () => Navigator.pop(sheet, true),
            ),
          ],
        ),
      ),
    );
    _asking = false;
    if (discard == true) exit();
  }
}
