import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'mdy_theme.dart';
import 'mdy_tokens.g.dart';

/// Trạng thái nhấn kiểu `onPressIn/onPressOut` của RN Pressable.
class MdyPressed extends StatefulWidget {
  const MdyPressed({super.key, required this.builder, this.onTap, this.enabled = true, this.behavior});

  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final bool enabled;
  final HitTestBehavior? behavior;

  @override
  State<MdyPressed> createState() => _MdyPressedState();
}

class _MdyPressedState extends State<MdyPressed> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      behavior: widget.behavior ?? HitTestBehavior.opaque,
      onTapDown: active ? (_) => _set(true) : null,
      onTapUp: active ? (_) => _set(false) : null,
      onTapCancel: active ? () => _set(false) : null,
      onTap: active ? widget.onTap : null,
      child: widget.builder(context, active && _pressed),
    );
  }
}

/// Margin âm phía trên (`-mt-space-N` của RN): kéo widget lên đè phần trước, layout co lại đúng N.
/// Vẫn nhận chạm ở phần bị kéo lên.
class MdyOverlap extends SingleChildRenderObjectWidget {
  const MdyOverlap({super.key, this.by = MdySpace.s64, super.child});
  final double by;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderMdyOverlap(by);

  @override
  void updateRenderObject(BuildContext context, covariant RenderMdyOverlap renderObject) {
    renderObject.by = by;
  }
}

/// RenderObject của [MdyOverlap].
class RenderMdyOverlap extends RenderShiftedBox {
  RenderMdyOverlap(this._by) : super(null);
  double _by;

  set by(double value) {
    if (value == _by) return;
    _by = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.constrain(Size.zero);
      return;
    }
    c.layout(constraints.loosen(), parentUsesSize: true);
    (c.parentData! as BoxParentData).offset = Offset(0, -_by);
    size = constraints.constrain(Size(c.size.width, math.max(0, c.size.height - _by)));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// `entering={FadeIn.duration(250)}` của Reanimated, tắt khi giảm chuyển động.
class MdyFadeIn extends StatefulWidget {
  const MdyFadeIn({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<MdyFadeIn> createState() => _MdyFadeInState();
}

class _MdyFadeInState extends State<MdyFadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: MdyMotion.base);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.enabled || context.mdyReducedMotion) {
      _c.value = 1;
    } else if (_c.status == AnimationStatus.dismissed) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _c, child: widget.child);
}

/// Đường kẻ mảnh `StyleSheet.hairlineWidth`.
double mdyHairline(BuildContext context) => 1 / MediaQuery.devicePixelRatioOf(context);

/// `boxShadow: 0px Ypx Blurpx color` của RN.
BoxShadow mdyShadow(Color color, double y, double blur) => BoxShadow(color: color, offset: Offset(0, y), blurRadius: blur);
