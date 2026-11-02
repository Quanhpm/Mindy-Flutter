import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/ui.dart';
import '../../core/ui/auto_carousel.dart';
import '../../core/ui/folded_paper.dart';
import '../../core/ui/paper_button.dart';

const _slides = ['first', 'second', 'third'];
const _mascots = ['map', 'laptop', 'book'];

/// HomeCarousel.tsx: dùng mascot đã bundle. RN chưa có ba ảnh intro; không tạo
/// khung ảnh trắng hoặc suy diễn ảnh học viên khi chưa có tài nguyên chính thức.
class HomeIntro extends ConsumerWidget {
  const HomeIntro({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              style: AppText.sectionTitle(AppColors.black),
              children: [
                TextSpan(text: t('home.intro.headingBefore')),
                TextSpan(
                  text: t('home.intro.headingAccent'),
                  style: const TextStyle(color: AppColors.mint),
                ),
                TextSpan(text: t('home.intro.headingAfter')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AutoCarousel(
          labels: [
            for (var i = 0; i < 3; i++)
              t('home.carousel.goToSlide', {'index': i + 1, 'title': t('home.intro.${_slides[i]}.title')}),
          ],
          pauseLabel: t('home.carousel.pause'),
          resumeLabel: t('home.carousel.resume'),
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(top: 52, bottom: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      color: [AppColors.sunshine, AppColors.logoSoft, AppColors.banner][i],
                      padding: const EdgeInsets.fromLTRB(18, 66, 18, 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              t('home.intro.${_slides[i]}.title'),
                              style: const TextStyle(
                                fontSize: 23,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: AppColors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t('home.intro.${_slides[i]}.description'),
                            style: const TextStyle(fontSize: 14.5, height: 1.6, color: AppColors.black),
                          ),
                          const SizedBox(height: 20),
                          PaperButton(label: t('home.intro.${_slides[i]}.action'), hint: t('home.actions.unavailable')),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -44,
                      left: i == 1 ? null : 14,
                      right: i == 1 ? 10 : null,
                      child: ExcludeSemantics(
                        child: Image.asset(
                          'assets/illustrations/mindy-mascot-${_mascots[i]}.png',
                          width: i == 1 ? 140 : 104,
                          height: 108,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class HomeAbout extends ConsumerWidget {
  const HomeAbout({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Container(
      color: AppColors.mint,
      padding: const EdgeInsets.fromLTRB(8, 26, 8, 16),
      child: Column(
        children: [
          Semantics(header: true, child: Text(t('home.sections.about'), style: AppText.title(AppColors.canvas))),
          AutoCarousel(
            activeColor: AppColors.canvas,
            controlColor: AppColors.black,
            inactiveColor: AppColors.line,
            labels: [
              for (var i = 0; i < 3; i++)
                t('home.carousel.goToSlide', {'index': i + 1, 'title': t('home.about.notes.${_slides[i]}.title')}),
            ],
            pauseLabel: t('home.carousel.pause'),
            resumeLabel: t('home.carousel.resume'),
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 32, 14, 24),
                  child: Transform.rotate(
                    angle: [-.028, .021, -.014][i],
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FoldedPaper(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  t('home.about.notes.${_slides[i]}.title'),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                t('home.about.notes.${_slides[i]}.description'),
                                style: const TextStyle(fontSize: 14.5, height: 1.6, color: AppColors.black),
                              ),
                              for (final point in ['one', 'two'])
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text.rich(
                                    TextSpan(
                                      style: const TextStyle(fontSize: 14.5, height: 1.6, color: AppColors.black),
                                      children: [
                                        TextSpan(text: t('home.about.dash')),
                                        TextSpan(
                                          text: t('home.about.notes.${_slides[i]}.${point}Bold'),
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                        TextSpan(text: ' ${t('home.about.notes.${_slides[i]}.${point}Text')}'),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: -12,
                          right: 30,
                          child: ExcludeSemantics(child: Container(width: 76, height: 24, color: AppColors.tape)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// HomeCompiler.tsx: chỉ minh họa, không chạy code hoặc chấm bài thật.
class HomeCompiler extends ConsumerWidget {
  const HomeCompiler({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 320 || MediaQuery.textScalerOf(context).scale(1) > 1.2;
        final card = Container(
          margin: EdgeInsets.only(left: stacked ? 0 : 52),
          padding: EdgeInsets.fromLTRB(stacked ? 18 : 110, 26, 18, 26),
          decoration: BoxDecoration(color: AppColors.logoSoft, borderRadius: BorderRadius.circular(32)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(t('home.sections.compiler'), style: AppText.title(AppColors.black))),
              const SizedBox(height: 14),
              for (final key in ['one', 'two', 'three'])
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.banner)),
                  ),
                  child: Text(
                    t('home.compiler.benefits.$key'),
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.black),
                  ),
                ),
              const SizedBox(height: 16),
              PaperButton(label: t('home.compiler.action'), hint: t('home.actions.unavailable')),
            ],
          ),
        );
        final terminal = _terminal(t);
        return Column(
          children: [
            if (stacked) ...[
              card,
              const SizedBox(height: 20),
              Center(child: terminal),
            ] else
              Stack(
                children: [
                  card,
                  Positioned(left: 0, top: 0, bottom: 0, width: 154, child: Center(child: terminal)),
                ],
              ),
            const SizedBox(height: 14),
            Text(t('home.compiler.illustration'), style: AppText.caption(AppColors.muted), textAlign: TextAlign.center),
          ],
        );
      },
    );
  }

  Widget _terminal(Translator t) => ExcludeSemantics(
    child: Transform.rotate(
      angle: -.07,
      child: Container(
        width: 154,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.forestDeep, borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: AppColors.forestNight,
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  for (final color in [AppColors.headsup, AppColors.sunshine, AppColors.mint])
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      t('home.compiler.terminal'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 8, color: AppColors.banner),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final key in ['command', 'running', 'hello', 'test1', 'test2', 'test3', 'complete', 'prompt'])
                    Row(
                      children: [
                        if (key.startsWith('test')) ...[
                          const MindyIcon(MindyIconName.check, size: 9, color: AppColors.aqua),
                          const SizedBox(width: 2),
                        ],
                        Expanded(
                          child: Text(
                            t('home.compiler.$key', {'name': name}).replaceFirst(RegExp(r'^✓\s*'), ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'RobotoMono',
                              fontSize: 8.5,
                              height: 1.8,
                              color: key.startsWith('test')
                                  ? AppColors.aqua
                                  : key == 'complete'
                                  ? AppColors.action
                                  : AppColors.canvas,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class HomeFooter extends ConsumerWidget {
  const HomeFooter({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Container(
      color: AppColors.forest,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(9)),
                child: Text(
                  t('home.brand.initial'),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.forest),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(t('auth.brandName'), style: AppText.title(AppColors.canvas))),
            ],
          ),
          const SizedBox(height: 10),
          Text(t('home.footer.tagline'), style: AppText.caption(AppColors.line)),
          const SizedBox(height: 18),
          Semantics(header: true, child: Text(t('home.footer.learn'), style: AppText.label(AppColors.sunshine))),
          for (final (label, route) in [
            ('home.tabs.courses', Routes.courses),
            ('home.tabs.schedule', Routes.schedule),
            ('home.footer.myClasses', Routes.myClasses('home')),
          ])
            Pressable(
              semanticLabel: t(label),
              onTap: () => label == 'home.footer.myClasses' ? context.push(route) : context.go(route),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t(label), style: AppText.caption(AppColors.canvas)),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(t('home.footer.copyright'), style: AppText.caption(AppColors.line)),
        ],
      ),
    );
  }
}
