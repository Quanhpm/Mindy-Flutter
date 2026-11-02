import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import 'reports_models.dart';

String rp(String key) => 'mdy.reports.$key';
String reportInstant(DateTime value, String zone) {
  DateTime d;
  try {
    d = tz.TZDateTime.from(value, tz.getLocation(zone));
  } catch (_) {
    d = value.toUtc().add(const Duration(hours: 7));
  }
  String two(int n) => '$n'.padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)} ${two(d.day)}/${two(d.month)}/${d.year}';
}

class ReportCountLines extends ConsumerWidget {
  const ReportCountLines({
    super.key,
    required this.counts,
    required this.prefix,
    this.large = false,
  });
  final ReportCounts counts;
  final String prefix;
  final bool large;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final rate = counts.rate;
    String rateText = rate == null
        ? '—'
        : rate.toString().replaceFirst(RegExp(r'\.0$'), '');
    if (t.locale.languageCode == 'vi') rateText = rateText.replaceAll('.', ',');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s6,
      children: [
        Text(
          rate == null ? rateText : '$rateText%',
          key: Key('$prefix-rate'),
          style: MdyType.size(
            large ? 26 : 17,
            MdyType.w700,
          ).copyWith(color: large ? context.mdy.link : context.mdy.ink),
        ),
        MdyText(
          rate == null
              ? t(rp('noFinalized'))
              : t(rp('denominator'), {
                  'present': counts.present,
                  'total': counts.eligible,
                }),
          key: Key('$prefix-denominator'),
        ),
        if (rate != null)
          MdyText(
            '${t(rp('present'), {'count': counts.present})} · ${t(rp('absent'), {'count': counts.absent})}',
          ),
        Wrap(
          spacing: MdySpace.s8,
          runSpacing: MdySpace.s6,
          children: [
            if (counts.makeupPending > 0)
              MdyChip(
                t(rp('makeupPending'), {'count': counts.makeupPending}),
                key: Key('$prefix-makeup'),
                variant: MdyChipVariant.warning,
              ),
            if (counts.unmarked > 0)
              MdyChip(
                t(rp('unmarked'), {'count': counts.unmarked}),
                key: Key('$prefix-unmarked'),
                variant: MdyChipVariant.neutral,
              ),
            if (counts.excluded > 0)
              MdyText(
                t(rp('excluded'), {'count': counts.excluded}),
                key: Key('$prefix-excluded'),
              ),
          ],
        ),
      ],
    );
  }
}

class ReportSummaryRow extends ConsumerWidget {
  const ReportSummaryRow({
    super.key,
    required this.item,
    required this.prefix,
    this.onTap,
  });
  final ReportEnrollment item;
  final String prefix;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = item.name ?? ref.watch(trProvider)(rp('noName')),
        id = '$prefix-row-${item.id}';
    return Semantics(
      button: onTap != null,
      child: MdyPressed(
        key: Key(id),
        onTap: onTap,
        builder: (context, pressed) => Opacity(
          opacity: pressed ? .8 : 1,
          child: MdyCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(MdySpace.s14),
            gap: MdySpace.s10,
            children: [
              Row(
                spacing: MdySpace.s12,
                children: [
                  MdyAvatar(name: name, size: 36),
                  Expanded(
                    child: Text(
                      name,
                      style: MdyType.size(
                        15,
                        MdyType.w600,
                      ).copyWith(color: context.mdy.ink),
                    ),
                  ),
                  if (onTap != null) const MdyIcon(MdyIcons.chevronRight),
                ],
              ),
              ReportCountLines(counts: item, prefix: id),
            ],
          ),
        ),
      ),
    );
  }
}
