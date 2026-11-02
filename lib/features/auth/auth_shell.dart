import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';

/// Khung chung cho Welcome/Login/Register.
/// TODO(UI): port chi tiết từ `modules/auth/components/AuthShell.tsx`
/// và `assets/Student Home Page Design/Auth.dc.html` (mascot, nền, bo góc).
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.title, this.description, required this.children, this.onBack});

  final String title;
  final String? description;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (onBack != null)
                    Pressable(
                      onTap: onBack,
                      semanticLabel: 'back',
                      child: const SizedBox.square(dimension: 44, child: Center(child: MindyIcon(MindyIconName.back))),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Center(child: Image.asset('assets/illustrations/mindy-mascot-laptop.png', height: 160)),
              const SizedBox(height: 16),
              Text(title, style: AppText.sectionTitle(AppColors.black)),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(description!, style: AppText.body(AppColors.inkGray)),
              ],
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Hộp báo lỗi/thành công dưới form - `components/FormFeedback.tsx`
class FormFeedback extends StatelessWidget {
  const FormFeedback({super.key, required this.message, this.requestId, this.success = false});
  final String message;
  final String? requestId;
  final bool success;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: success ? AppColors.soft : AppColors.peach,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            requestId == null ? message : '$message\n#$requestId',
            style: TextStyle(fontWeight: FontWeight.w600, color: success ? AppColors.forest : AppColors.headsup),
          ),
        ),
      );
}
