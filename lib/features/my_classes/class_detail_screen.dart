import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_error.dart';
import '../../core/ui/ui.dart';
import 'my_classes_models.dart';
import 'my_classes_providers.dart';

/// Chi tiết lớp - `my-classes/ClassDetailScreen.tsx`.
/// Có `sessionId` -> hiện chi tiết buổi (`SessionDetailScreen.tsx`) như view con, không phải route riêng.
/// FULL: có link Google Meet. CASH_PREVIEW: chỉ xem trước, KHÔNG có link.
/// TODO(UI): port thông tin giáo viên + sheet người tham gia (ClassParticipantsSheet), "Xem thêm/Thu gọn".
class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({super.key, required this.classId, this.sessionId});
  final String classId;
  final String? sessionId;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  late String? _sessionId = widget.sessionId;
  String? _linkError;

  Future<void> _open(String url) async {
    final t = ref.read(trProvider);
    setState(() => _linkError = null);
    final uri = Uri.tryParse(url);
    final ok = uri != null && (uri.scheme == 'https' || uri.scheme == 'http') &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) setState(() => _linkError = t('classDetail.linkError'));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final detail = ref.watch(classDetailProvider(widget.classId));

    return PopScope(
      // Đang xem buổi -> Back quay về danh sách buổi của lớp
      canPop: _sessionId == null || widget.sessionId != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _sessionId = null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('classDetail.title')),
          leading: IconButton(
            tooltip: t('learning.back'),
            icon: const MindyIcon(MindyIconName.back),
            onPressed: () {
              if (_sessionId != null && widget.sessionId == null) {
                setState(() => _sessionId = null);
              } else {
                context.canPop() ? context.pop() : context.go(Routes.home);
              }
            },
          ),
        ),
        body: detail.when(
          loading: () => const Padding(padding: EdgeInsets.all(20), child: Skeleton(height: 240)),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: ScreenState(
              title: t(e is ApiError && e.status == 404 ? 'classDetail.notFound' : 'classDetail.denied'),
              description: t('classDetail.returnToList'),
              requestId: requestIdOf(e),
              onRetry: () => ref.invalidate(classDetailProvider(widget.classId)),
            ),
          ),
          data: (r) => _sessionId == null ? _classView(t, r.detail) : _sessionView(t, r.detail, _sessionId!),
        ),
      ),
    );
  }

  Widget _classView(Translator t, ClassDetail d) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (d.isPreview)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppColors.sunshine, borderRadius: BorderRadius.circular(16)),
            child: Text(t('classDetail.preview'), style: AppText.label(AppColors.black)),
          ),
        Text(d.name, style: AppText.sectionTitle(AppColors.forest)),
        Text(d.code, style: AppText.caption(AppColors.muted)),
        const SizedBox(height: 12),
        _info(t('classDetail.startDate'), Dates.displayDay(d.startDate)),
        _info(t('classDetail.endDate'), Dates.displayDay(d.endDate)),
        _info(t('classDetail.deliveryLabel'), t('learning.delivery.${d.deliveryMode.name}')),
        _info(t('classDetail.mentorLabel'), d.mentorName ?? t('classDetail.noMentor')),
        if (!d.isPreview && d.meetingUrl != null) ...[
          const SizedBox(height: 12),
          MindyButton(label: t('classDetail.join'), onPressed: () => _open(d.meetingUrl!)),
        ],
        if (_linkError != null) Text(_linkError!, style: const TextStyle(color: AppColors.headsup)),
        const SizedBox(height: 20),
        Text(t('classDetail.sessionCount', {'count': d.sessions.length}), style: AppText.title(AppColors.forest)),
        if (d.units.isEmpty) Text(t('classDetail.noUnits')),
        for (final u in d.units) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(u.title, style: AppText.label(AppColors.forest)),
          ),
          for (final s in u.sessions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${t('classDetail.sessionNumber', {'number': s.sessionNumber})} · ${s.title}'),
              // TODO: timeZone lấy từ response khi contract có; tạm dùng giờ VN như mặc định schedule
              subtitle: Text(
                  '${Dates.instant(s.startsAt, 'Asia/Ho_Chi_Minh')} · ${t('learning.sessionStatus.${s.status.name}')}'),
              trailing: const MindyIcon(MindyIconName.arrow, size: 18),
              onTap: () => setState(() => _sessionId = s.id),
            ),
        ],
      ],
    );
  }

  Widget _sessionView(Translator t, ClassDetail d, String sessionId) {
    final matches = d.sessions.where((s) => s.id == sessionId);
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ScreenState(title: t('classDetail.missingSession'), description: t('classDetail.returnToList')),
      );
    }
    final s = matches.first;
    const zone = 'Asia/Ho_Chi_Minh';
    // Link họp chỉ khi FULL và buổi chưa kết thúc/huỷ
    final url = d.isPreview ? null : (s.meetingUrl ?? d.meetingUrl);
    final joinable = url != null && s.status != SessionStatus.CANCELLED && s.endsAt.isAfter(DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(t('classDetail.session.heading', {'code': d.code, 'number': s.sessionNumber, 'total': d.sessions.length}),
            style: AppText.caption(AppColors.muted)),
        Text(s.title, style: AppText.sectionTitle(AppColors.forest)),
        const SizedBox(height: 12),
        _info(t('classDetail.session.date'), Dates.displayDay(Dates.localDay(s.startsAt, zone))),
        _info(t('classDetail.session.time'), '${Dates.time(s.startsAt, zone)} – ${Dates.time(s.endsAt, zone)}'),
        _info(t('classDetail.session.room'), s.roomName ?? t('classDetail.noRoom')),
        const SizedBox(height: 16),
        Text(t('classDetail.session.content'), style: AppText.label(AppColors.forest)),
        Text(t('classDetail.session.noContent'), style: AppText.caption(AppColors.muted)),
        const SizedBox(height: 12),
        Text(t('classDetail.session.objectives'), style: AppText.label(AppColors.forest)),
        Text(t('classDetail.session.noObjectives'), style: AppText.caption(AppColors.muted)),
        const SizedBox(height: 24),
        if (joinable) MindyButton(label: t('classDetail.join'), onPressed: () => _open(url)),
        if (_linkError != null) Text(_linkError!, style: const TextStyle(color: AppColors.headsup)),
      ],
    );
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 120, child: Text(label, style: AppText.caption(AppColors.muted))),
          Expanded(child: Text(value, style: AppText.label(AppColors.forest))),
        ]),
      );
}
