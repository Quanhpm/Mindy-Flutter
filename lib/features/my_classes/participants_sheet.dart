import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/button.dart';

/// Sheet danh sách người tham gia lớp - `modules/my-classes/components/ClassParticipantsSheet.tsx`.
class ClassParticipantsSheet extends ConsumerWidget {
  const ClassParticipantsSheet({
    super.key,
    required this.mentorName,
    required this.classCode,
  });

  final String? mentorName;
  final String classCode;

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .toList();
    if (parts.isEmpty) return '?';
    final slice = parts.length > 2 ? parts.sublist(parts.length - 2) : parts;
    return slice.join().toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);

    return ListView(
      shrinkWrap: true,
      controller: PrimaryScrollController.of(context),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Container(
          key: const Key('class-participants-sheet'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  t('classDetail.mentorLabel'),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (mentorName != null && mentorName!.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.soft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.sunshine,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(mentorName!),
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.mint,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mentorName!,
                              key: const Key('class-participants-mentor'),
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              t('classDetail.participants.mentorClass', {'code': classCode}),
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  t('classDetail.noMentor'),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: AppColors.muted,
                  ),
                ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  t('classDetail.participants.students'),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.soft,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Text(
                  t('classDetail.participants.pending'),
                  key: const Key('class-participants-pending'),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    height: 22 / 14,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              MindyButton(
                key: const Key('class-participants-close'),
                label: t('common.close'),
                variant: ButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
