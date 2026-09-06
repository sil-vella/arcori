import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Stack camera floor — discs and mural share this so max zoom-out is contain.
/// Rest zoom is `1 / this` (~4.5×); slightly less tight than 0.18.
const double kStackPovFitMin = 0.22;

/// Critically-damped zoom follow (~0.75s settle). Restarting a 200ms tween
/// every stack-fit tick made pullback feel stepped.
const double kPovZoomSmoothTime = 0.75;

/// SmoothDamp toward [target]. Returns the next value and velocity.
({double value, double velocity}) povZoomSmoothDamp({
  required double current,
  required double target,
  required double velocity,
  required double dt,
  double smoothTime = kPovZoomSmoothTime,
}) {
  final st = math.max(0.0001, smoothTime);
  final omega = 2.0 / st;
  final x = omega * dt;
  final exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x);
  var change = current - target;
  final originalTo = target;
  target = current - change;
  final temp = (velocity + omega * change) * dt;
  velocity = (velocity - omega * temp) * exp;
  var output = target + (change + temp) * exp;
  if ((originalTo - current > 0.0) == (output > originalTo)) {
    output = originalTo;
    velocity = 0.0;
  }
  return (value: output, velocity: velocity);
}

/// Camera scale applied to the rest-sized mural + discs.
///
/// Rest ([stackFit] 1) is **1.0** (pixel-perfect). Max zoom-out is
/// [stackFitMin] (the oversized mural becomes contain). Never scale a
/// screen-fitted bitmap *up* — that is what made the table and Arcori look
/// pixelated.
double arenaPovContainScale({
  required double stackFit,
  double stackFitMin = kStackPovFitMin,
}) {
  final minFit = stackFitMin.clamp(1e-6, 1.0);
  return stackFit.clamp(minFit, 1.0);
}

/// Paint scale for Arcori in the rest-sized world (always 1).
///
/// Discs are drawn at rest Ø; the shared camera only scales them down.
double arenaWorldDiscScale({double stackFitMin = kStackPovFitMin}) => 1.0;

Alignment arenaPovAlignment({
  required RenderBox backdrop,
  required RenderBox stackArea,
}) {
  final center = stackArea.localToGlobal(stackArea.size.center(Offset.zero));
  final local = backdrop.globalToLocal(center);
  final w = backdrop.size.width;
  final h = backdrop.size.height;
  if (w <= 0 || h <= 0) return Alignment.center;
  return Alignment(
    (local.dx / w) * 2 - 1,
    (local.dy / h) * 2 - 1,
  );
}

Rect? arenaPovStackRect({
  required RenderBox backdrop,
  required RenderBox stackArea,
}) {
  if (!backdrop.hasSize || !stackArea.hasSize) return null;
  final origin = backdrop.globalToLocal(stackArea.localToGlobal(Offset.zero));
  return origin & stackArea.size;
}

/// Arena mural + table pieces in one camera: zoomed in at rest, contain at max zoom-out.
class ArenaPovBackdrop extends StatefulWidget {
  const ArenaPovBackdrop({
    super.key,
    required this.imageUrl,
    required this.povScale,
    required this.stackAreaKey,
    this.stackLayer,
  });

  final String imageUrl;
  final ValueNotifier<double> povScale;
  final GlobalKey stackAreaKey;

  /// Table pieces at rest Ø. Same transform as the mural; painted above it.
  final Widget? stackLayer;

  @override
  State<ArenaPovBackdrop> createState() => _ArenaPovBackdropState();
}

class _ArenaPovBackdropState extends State<ArenaPovBackdrop>
    with SingleTickerProviderStateMixin {
  bool _alignScheduled = false;
  int _alignTries = 0;
  late final Ticker _zoomTicker;
  late final ValueNotifier<double> _visual;
  double _targetVisual = 1.0;
  double _zoomVelocity = 0.0;
  Duration? _lastZoomElapsed;

  @override
  void initState() {
    super.initState();
    _targetVisual = arenaPovContainScale(stackFit: widget.povScale.value);
    _visual = ValueNotifier<double>(_targetVisual);
    _zoomTicker = createTicker(_onZoomTick);
    widget.povScale.addListener(_onPovScale);
  }

  @override
  void didUpdateWidget(covariant ArenaPovBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.povScale != widget.povScale) {
      oldWidget.povScale.removeListener(_onPovScale);
      widget.povScale.addListener(_onPovScale);
      _onPovScale();
    }
  }

  void _onPovScale() {
    _targetVisual = arenaPovContainScale(stackFit: widget.povScale.value);
    if (!_zoomTicker.isActive) {
      _lastZoomElapsed = null;
      _zoomTicker.start();
    }
  }

  void _onZoomTick(Duration elapsed) {
    final last = _lastZoomElapsed ?? elapsed;
    _lastZoomElapsed = elapsed;
    var dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0) dt = 1 / 60;
    if (dt > 0.05) dt = 0.05;
    final next = povZoomSmoothDamp(
      current: _visual.value,
      target: _targetVisual,
      velocity: _zoomVelocity,
      dt: dt,
    );
    _visual.value = next.value;
    _zoomVelocity = next.velocity;
    if ((_visual.value - _targetVisual).abs() < 0.00035 &&
        _zoomVelocity.abs() < 0.002) {
      _visual.value = _targetVisual;
      _zoomVelocity = 0;
      _zoomTicker.stop();
      _lastZoomElapsed = null;
    }
  }

  @override
  void dispose() {
    widget.povScale.removeListener(_onPovScale);
    _zoomTicker.dispose();
    _visual.dispose();
    super.dispose();
  }

  Alignment? _tryAlign(BuildContext context) {
    final stackBox = widget.stackAreaKey.currentContext?.findRenderObject();
    final here = context.findRenderObject();
    if (stackBox is! RenderBox || here is! RenderBox) return null;
    if (!stackBox.hasSize || !here.hasSize) return null;
    return arenaPovAlignment(backdrop: here, stackArea: stackBox);
  }

  Rect? _tryStackRect(BuildContext context) {
    final stackBox = widget.stackAreaKey.currentContext?.findRenderObject();
    final here = context.findRenderObject();
    if (stackBox is! RenderBox || here is! RenderBox) return null;
    return arenaPovStackRect(backdrop: here, stackArea: stackBox);
  }

  void _scheduleAlignRefresh() {
    if (_alignScheduled || _alignTries >= 8) return;
    _alignScheduled = true;
    _alignTries++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alignScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final align = _tryAlign(context);
        final slot = _tryStackRect(context);
        if (align == null || (widget.stackLayer != null && slot == null)) {
          _scheduleAlignRefresh();
        }
        final slotLeft = slot?.left ?? 0.0;
        final slotTop = slot?.top ??
            (constraints.maxHeight - 220).clamp(0.0, double.infinity) / 2;
        final slotW = slot?.width ?? constraints.maxWidth;
        final slotH = slot?.height ?? 220.0;
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final worldW = maxW.isFinite && maxW > 0
            ? maxW / kStackPovFitMin
            : maxW;
        final worldH = maxH.isFinite && maxH > 0
            ? maxH / kStackPovFitMin
            : maxH;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheW = worldW.isFinite && worldW > 0
            ? (worldW * dpr).round().clamp(1, 8192)
            : null;
        final origin = align ?? Alignment.center;
        return ClipRect(
          child: ValueListenableBuilder<double>(
            valueListenable: _visual,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                alignment: origin,
                child: child,
              );
            },
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: OverflowBox(
                    alignment: origin,
                    minWidth: worldW,
                    maxWidth: worldW,
                    minHeight: worldH,
                    maxHeight: worldH,
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                      cacheWidth: cacheW,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                if (widget.stackLayer != null)
                  Positioned(
                    left: slotLeft,
                    top: slotTop,
                    width: slotW,
                    height: slotH,
                    child: IgnorePointer(child: widget.stackLayer),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
