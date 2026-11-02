import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'pressable.dart';

/// Carousel 3 giây theo useCarouselAutoplay.ts. Row có chiều cao tự nhiên theo
/// nội dung dài nhất, tránh đặt chiều cao cứng làm cắt chữ lớn/tiếng Anh.
class AutoCarousel extends StatefulWidget {
  const AutoCarousel({
    super.key,
    required this.children,
    required this.labels,
    required this.pauseLabel,
    required this.resumeLabel,
    this.onChanged,
    this.activeColor = AppColors.black,
    this.inactiveColor = AppColors.banner,
    this.controlColor,
    this.autoplay = true,
  }) : assert(children.length == labels.length && children.length > 0);
  final List<Widget> children;
  final List<String> labels;
  final String pauseLabel, resumeLabel;
  final ValueChanged<int>? onChanged;
  final Color activeColor, inactiveColor;
  final Color? controlColor;
  final bool autoplay;
  @override
  State<AutoCarousel> createState() => _AutoCarouselState();
}

class _AutoCarouselState extends State<AutoCarousel> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _scroll = ScrollController();
  Timer? _timer;
  int _index = 0;
  double _width = 0;
  bool _appActive = true, _routeActive = true, _systemPaused = false, _paused = false, _scrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _systemPaused = media.disableAnimations || media.accessibleNavigation;
    _routeActive = ModalRoute.of(context)?.isCurrent ?? true;
    _syncTimer();
  }

  @override
  void didUpdateWidget(AutoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.children.length) {
      _index = widget.children.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(_index * _width);
      });
    }
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!widget.autoplay ||
        widget.children.length <= 1 ||
        !_appActive ||
        !_routeActive ||
        _systemPaused ||
        _paused ||
        _scrolling ||
        _width <= 0) {
      return;
    }
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _select((_index + 1) % widget.children.length, wrap: true),
    );
  }

  void _select(int index, {bool wrap = false}) {
    if (!_scroll.hasClients || _width <= 0) return;
    setState(() => _index = index);
    widget.onChanged?.call(index);
    if (_systemPaused || (wrap && index == 0)) {
      _scroll.jumpTo(index * _width);
    } else {
      _scroll.animateTo(index * _width, duration: Motion.base, curve: Motion.curve);
    }
    _syncTimer();
  }

  bool _onScroll(ScrollNotification event) {
    if (event.depth != 0) return false;
    if (event is ScrollStartNotification) {
      _scrolling = true;
      _syncTimer();
    } else if (event is ScrollEndNotification) {
      final next = (event.metrics.pixels / _width).round().clamp(0, widget.children.length - 1);
      if (next != _index) {
        setState(() => _index = next);
        widget.onChanged?.call(next);
      }
      _scrolling = false;
      _syncTimer();
    }
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_width != constraints.maxWidth) {
          _width = constraints.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) return;
            _scroll.jumpTo(_index * _width);
            _syncTimer();
          });
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: const PageScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < widget.children.length; i++)
                      ExcludeSemantics(
                        excluding: i != _index,
                        child: SizedBox(width: constraints.maxWidth, child: widget.children[i]),
                      ),
                  ],
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < widget.children.length; i++)
                  Pressable(
                    semanticLabel: widget.labels[i],
                    selected: _index == i,
                    onTap: () => _select(i),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: Container(
                          width: _index == i ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _index == i ? widget.activeColor : widget.inactiveColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.autoplay && widget.children.length > 1 && !_systemPaused)
              Pressable(
                semanticLabel: _paused ? widget.resumeLabel : widget.pauseLabel,
                onTap: () {
                  setState(() => _paused = !_paused);
                  _syncTimer();
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                  child: Center(
                    child: Text(
                      _paused ? widget.resumeLabel : widget.pauseLabel,
                      style: AppText.caption(widget.controlColor ?? widget.activeColor),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
