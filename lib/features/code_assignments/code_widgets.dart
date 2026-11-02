import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/states.dart';
import 'code_models.dart';

/// Mã lỗi bài code có câu riêng (`code.errors.*`); mã khác dùng bảng lỗi chung.
const codeErrorCodes = {
  'ASSIGNMENT_CLOSED',
  'ASSIGNMENT_DEADLINE_PASSED',
  'ASSIGNMENT_NOT_FOUND',
  'CODE_ATTEMPTS_EXHAUSTED',
  'CODE_CUSTOM_INPUT_INVALID',
  'CODE_DRAFT_VERSION_CONFLICT',
  'CODE_LANGUAGE_NOT_ALLOWED',
  'CODE_RUNNER_BUSY',
  'CODE_RUNNER_UNAVAILABLE',
  'CODE_RUN_RATE_LIMITED',
  'CODE_SOURCE_TOO_LARGE',
  'CODE_SUBMISSION_IN_FLIGHT',
  'CODE_SUBMISSION_NOT_FOUND',
  'IDEMPOTENCY_KEY_REUSED',
  'SUBMISSION_ACCESS_DENIED',
};

String codeErrorKey(Object error) =>
    error is ApiError && codeErrorCodes.contains(error.code) ? 'code.errors.${error.code}' : errorKey(error);

/// `8.50 / 10.00`
String scoreText(String? score, String maxScore) => '${score ?? '—'} / $maxScore';

/// Tông màu theo kết quả: đạt = xanh, đang chờ = vàng, còn lại = đỏ.
Color verdictColor(String? verdict, SubmissionStatus status) => switch (status) {
  SubmissionStatus.QUEUED || SubmissionStatus.RUNNING => AppColors.statusYellow,
  SubmissionStatus.FAILED || SubmissionStatus.VOIDED => AppColors.muted,
  SubmissionStatus.GRADED => verdict == 'ACCEPTED' ? AppColors.statusGreen : AppColors.statusRed,
};

Color testColor(String status) => switch (status) {
  'PASSED' || 'COMPLETED' => AppColors.statusGreen,
  _ => AppColors.statusRed,
};

/// Nhãn trạng thái của một bài nộp.
String submissionLabel(Translator t, Submission s) => switch (s.status) {
  SubmissionStatus.GRADED => t('code.verdict.${s.verdict}'),
  _ => t('code.status.${s.status.name}'),
};

class CodePill extends StatelessWidget {
  const CodePill(this.label, {super.key, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
  );
}

class CodeSectionTitle extends StatelessWidget {
  const CodeSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.black)),
    ),
  );
}

/// Khối code/kết quả đơn cách, chọn và sao chép được.
class CodeBlock extends StatelessWidget {
  const CodeBlock(this.text, {super.key, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(12)),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SelectableText(
        text,
        style: TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 12.5,
          height: 1.45,
          color: error ? AppColors.statusRed : AppColors.inkSoft,
        ),
      ),
    ),
  );
}

/// Ô thông tin nhỏ (nhãn trên, giá trị dưới) dạng lưới 2 cột như màn Chi tiết buổi.
class CodeFact extends StatelessWidget {
  const CodeFact({super.key, required this.label, required this.value, this.highlight = false});
  final String label, value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: highlight ? AppColors.peach : AppColors.soft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.ember : AppColors.black,
          ),
        ),
      ],
    ),
  );
}

/// Lưới ô thông tin co giãn theo bề rộng (2 cột; 1 cột khi màn hẹp + chữ lớn).
class CodeFacts extends StatelessWidget {
  const CodeFacts(this.facts, {super.key});
  final List<CodeFact> facts;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = box.maxWidth < 300 || (box.maxWidth < 360 && scale >= 1.3) ? 1 : 2;
      final width = (box.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final fact in facts) SizedBox(width: width, child: fact)],
      );
    },
  );
}

/// Câu lỗi + mã yêu cầu (nếu có), đọc được bởi trình đọc màn hình.
class CodeErrorText extends StatelessWidget {
  const CodeErrorText(this.error, {super.key, required this.t});
  final Object error;
  final Translator t;

  @override
  Widget build(BuildContext context) {
    final id = requestIdOf(error);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          id == null ? t(codeErrorKey(error)) : '${t(codeErrorKey(error))} ${t('common.requestId', {'id': id})}',
          style: const TextStyle(fontSize: 14, color: AppColors.statusRed),
        ),
      ),
    );
  }
}
