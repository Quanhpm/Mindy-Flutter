import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/ui.dart';
import '../../core/ui/auto_carousel.dart';
import '../../core/ui/folded_paper.dart';

const _slides = ['first', 'second', 'third'];
const _mascots = ['map', 'laptop', 'book'];

/// HomeCarousel.tsx kind="intro": tiêu đề 28, khung ảnh 4:3 teal, mascot, nút giấy.
class HomeIntro extends ConsumerWidget {
  const HomeIntro({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 30.8 / 28,
                    letterSpacing: -0.84,
                    color: AppColors.black,
                  ),
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
          ),
          const SizedBox(height: 12),
          AutoCarousel(
            labels: [
              for (var i = 0; i < 3; i++)
                t('home.carousel.goToSlide', {
                  'index': i + 1,
                  'title': t('home.intro.${_slides[i]}.title'),
                }),
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
                        padding: const EdgeInsets.fromLTRB(18, 66, 18, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                t('home.intro.${_slides[i]}.title'),
                                style: const TextStyle(
                                  fontSize: 23,
                                  height: 27.6 / 23,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.46,
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t('home.intro.${_slides[i]}.description'),
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 23.2 / 14.5,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Khung ảnh 4:3 bg-teal p-9 shadow-lg (RN HomeCarousel dòng 219-238)
                            Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.all(9),
                              decoration: const BoxDecoration(
                                color: AppColors.teal,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x3312302E),
                                    blurRadius: 15,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const AspectRatio(
                                aspectRatio: 4 / 3,
                                child: ColoredBox(color: Color(0x99FFFFFF)),
                              ),
                            ),
                            HomeButton(
                              label: t('home.intro.${_slides[i]}.action'),
                              hint: t('home.actions.unavailable'),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: i == 1 ? -50 : (i == 2 ? -36 : -44),
                        left: i == 1 ? null : (i == 2 ? null : 14),
                        right: i == 1 ? 10 : null,
                        child: ExcludeSemantics(
                          child: Image.asset(
                            'assets/illustrations/mindy-mascot-${_mascots[i]}.png',
                            width: i == 1 ? 140 : (i == 2 ? 76 : 104),
                            height: i == 1 ? 112 : (i == 2 ? 91 : 107),
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
      ),
    );
  }
}

/// HomeCarousel.tsx kind="about": tràn ngang, nền mint, hai vòng tròn trang trí, giấy ghi chú gấp góc.
class HomeAbout extends ConsumerWidget {
  const HomeAbout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Container(
      color: AppColors.mint,
      padding: const EdgeInsets.only(top: 6, bottom: 30),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Vòng tròn trang trí top left
          Positioned(
            left: -40,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.canvas.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Vòng tròn trang trí bottom right
          Positioned(
            right: -50,
            bottom: 40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.canvas.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            children: [
              AutoCarousel(
                activeColor: AppColors.canvas,
                controlColor: AppColors.black,
                inactiveColor: AppColors.line,
                labels: [
                  for (var i = 0; i < 3; i++)
                    t('home.carousel.goToSlide', {
                      'index': i + 1,
                      'title': t('home.about.notes.${_slides[i]}.title'),
                    }),
                ],
                pauseLabel: t('home.carousel.pause'),
                resumeLabel: t('home.carousel.resume'),
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 40, 26, 26),
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
                                        height: 29.9 / 26,
                                        fontWeight: FontWeight.w800,
                                        fontStyle: FontStyle.italic,
                                        letterSpacing: -0.46,
                                        color: AppColors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    t('home.about.notes.${_slides[i]}.description'),
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      height: 23.2 / 14.5,
                                      color: AppColors.black,
                                    ),
                                  ),
                                  for (final point in ['one', 'two'])
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Text.rich(
                                        TextSpan(
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            height: 23.2 / 14.5,
                                            color: AppColors.black,
                                          ),
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
                            // Băng dính
                            Positioned(
                              top: 28,
                              right: [52.0, 140.0, 70.0][i],
                              child: Transform.rotate(
                                angle: [0.087, -0.07, 0.052][i],
                                child: ExcludeSemantics(
                                  child: Container(
                                    width: 76,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.tape.withValues(alpha: 0.8),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x1A000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// HomeCompiler.tsx: minh họa compiler, màu terminal chuẩn RN.
class HomeCompiler extends ConsumerWidget {
  const HomeCompiler({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 320 || MediaQuery.textScalerOf(context).scale(1) > 1.2;
          final card = Container(
            margin: EdgeInsets.only(left: stacked ? 0 : 52),
            padding: EdgeInsets.fromLTRB(stacked ? 18 : 110, 26, 18, 26),
            decoration: BoxDecoration(
              color: AppColors.logoSoft,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    t('home.sections.compiler'),
                    style: const TextStyle(
                      fontSize: 21,
                      height: 25.2 / 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < 3; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        top: const BorderSide(color: Color(0x331D5B57)),
                        bottom: i == 2 ? const BorderSide(color: Color(0x331D5B57)) : BorderSide.none,
                      ),
                    ),
                    child: Text(
                      t('home.compiler.benefits.${['one', 'two', 'three'][i]}'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 19.6 / 14.5,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: HomeButton(
                    key: const Key('home-compiler-button'),
                    label: t('home.compiler.action'),
                    minHeight: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    hint: t('home.actions.unavailable'),
                  ),
                ),
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
                  alignment: Alignment.centerLeft,
                  children: [
                    card,
                    Positioned(
                      left: 0,
                      child: terminal,
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              Text(
                t('home.compiler.illustration'),
                style: AppText.caption(AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _terminal(Translator t) => ExcludeSemantics(
        child: Transform.rotate(
          angle: -.07,
          child: Container(
            width: 154,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.forestDeep,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x5912302E), // forest-deep/35
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: AppColors.forestNight,
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
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
                          style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 8,
                            color: AppColors.banner,
                          ),
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
                      for (final key in [
                        'command',
                        'running',
                        'hello',
                        'test1',
                        'test2',
                        'test3',
                        'complete',
                      ])
                        Text(
                          t('home.compiler.$key', {'name': name}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 8.5,
                            height: 15.3 / 8.5,
                            color: key == 'running'
                                ? AppColors.banner
                                : key.startsWith('test')
                                    ? AppColors.aqua
                                    : key == 'complete'
                                        ? AppColors.action
                                        : AppColors.canvas,
                          ),
                        ),
                      Row(
                        children: [
                          Text(
                            t('home.compiler.prompt'),
                            style: const TextStyle(
                              fontFamily: 'RobotoMono',
                              fontSize: 8.5,
                              height: 15.3 / 8.5,
                              color: AppColors.sunshine,
                            ),
                          ),
                          Container(width: 5, height: 10, color: AppColors.canvas),
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

/// HomeFooter: tràn ngang, logo, tagline, cột learn, contact, session controls, copyright.
class HomeFooter extends ConsumerWidget {
  const HomeFooter({super.key, this.sessionControls});

  final Widget? sessionControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final insets = MediaQuery.paddingOf(context);

    return Container(
      key: const Key('home-footer'),
      color: AppColors.forest,
      padding: EdgeInsets.fromLTRB(16, 28, 16, 130 + insets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  t('home.brand.initial'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t('auth.brandName'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.canvas,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 18),
            child: Text(
              t('home.footer.tagline'),
              style: const TextStyle(
                fontSize: 14,
                height: 21.7 / 14,
                color: AppColors.line,
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('home.footer.learn'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.sunshine,
                  ),
                ),
                const SizedBox(height: 8),
                for (final (label, route, testId) in [
                  ('home.tabs.courses', Routes.courses, 'home-footer-courses'),
                  ('home.tabs.schedule', Routes.schedule, 'home-footer-schedule'),
                  ('home.footer.myClasses', Routes.myClasses('home'), 'home-my-classes'),
                ])
                  Pressable(
                    key: Key(testId),
                    semanticLabel: t(label),
                    onTap: () => testId == 'home-my-classes' ? context.push(route) : context.go(route),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t(label),
                          style: const TextStyle(fontSize: 14, color: AppColors.canvas),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              t('home.footer.contact'),
              style: const TextStyle(
                fontSize: 13.5,
                height: 23 / 13.5,
                color: AppColors.line,
              ),
            ),
          ),
          ?sessionControls,
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.canvas.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Text(
              t('home.footer.copyright'),
              style: const TextStyle(fontSize: 12, color: AppColors.banner),
            ),
          ),
        ],
      ),
    );
  }
}
