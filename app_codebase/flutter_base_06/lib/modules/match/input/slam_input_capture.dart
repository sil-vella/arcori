import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../utils/dev_logger.dart';
import 'slam_input_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Minimum downward drag (logical px) before a swipe commit is allowed.
const double kMinDownSwipeDy = 12;

typedef SlamInputCommitCallback = void Function(SlamInputPayload payload);

/// Captures swipe-down and/or phone shake during an armed turn window.
class SlamInputCapture extends StatefulWidget {
  const SlamInputCapture({
    super.key,
    required this.armed,
    required this.onCommit,
    required this.child,
    this.minDownSwipeDy = kMinDownSwipeDy,
    this.minShakeMps2 = kMinShakeMps2,
    this.minRawShakeDelta = kMinRawShakeDelta,
  });

  final bool armed;
  final SlamInputCommitCallback onCommit;
  final Widget child;
  final double minDownSwipeDy;
  final double minShakeMps2;
  final double minRawShakeDelta;

  @override
  State<SlamInputCapture> createState() => _SlamInputCaptureState();
}

class _SlamInputCaptureState extends State<SlamInputCapture> {
  double _dragDx = 0;
  double _dragDy = 0;
  double _peakMotion = 0;
  double _peakX = 0;
  double _peakY = 0;
  double _peakZ = 0;
  StreamSubscription<UserAccelerometerEvent>? _userMotionSub;
  StreamSubscription<AccelerometerEvent>? _rawMotionSub;
  bool _userMotionLive = false;
  bool _rawMotionLive = false;
  bool _committed = false;

  bool get _motionAvailable =>
      !kIsWeb && (_userMotionLive || _rawMotionLive);

  @override
  void didUpdateWidget(covariant SlamInputCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.armed && !oldWidget.armed) {
      _resetSession();
      _startMotion();
      if (LOGGING_SWITCH) {
        customlog('slamInput: armed (shake+swipe listening)');
      }
    } else if (!widget.armed && oldWidget.armed) {
      if (LOGGING_SWITCH && !_committed) {
        customlog(
          'slamInput: disarmed without commit '
          'peakMotion=${_peakMotion.toStringAsFixed(2)} '
          'userMotion=$_userMotionLive rawMotion=$_rawMotionLive',
        );
      }
      _stopMotion();
      _resetSession();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.armed) {
      _startMotion();
    }
  }

  @override
  void dispose() {
    _stopMotion();
    super.dispose();
  }

  void _resetSession() {
    _dragDx = 0;
    _dragDy = 0;
    _peakMotion = 0;
    _peakX = 0;
    _peakY = 0;
    _peakZ = 0;
    _committed = false;
  }

  void _notePeak(double x, double y, double z, double metric) {
    if (metric >= _peakMotion) {
      _peakMotion = metric;
      _peakX = x;
      _peakY = y;
      _peakZ = z;
    }
  }

  void _onUserMotion(UserAccelerometerEvent event) {
    if (!widget.armed || _committed) return;
    final mag = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    _notePeak(event.x, event.y, event.z, mag);
    if (mag >= widget.minShakeMps2) {
      _commitFromShake(
        motionPeakMagnitude: mag,
        motionPeakX: event.x,
        motionPeakY: event.y,
        motionPeakZ: event.z,
        source: 'shake',
      );
    }
  }

  void _onRawMotion(AccelerometerEvent event) {
    if (!widget.armed || _committed) return;
    final mag = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final delta = (mag - gravityMps2).abs();
    _notePeak(event.x, event.y, event.z, max(delta, _peakMotion));
    if (delta >= widget.minRawShakeDelta) {
      _commitFromShake(
        motionPeakMagnitude: delta.clamp(0.0, motionMaxMps2),
        motionPeakX: event.x,
        motionPeakY: event.y,
        motionPeakZ: event.z,
        source: 'shake_raw',
      );
    }
  }

  void _startMotion() {
    if (kIsWeb) return;

    _userMotionSub?.cancel();
    _rawMotionSub?.cancel();
    _userMotionLive = false;
    _rawMotionLive = false;

    _userMotionSub = userAccelerometerEventStream().listen(
      _onUserMotion,
      onError: (Object err) {
        _userMotionLive = false;
        if (LOGGING_SWITCH) {
          customlog('slamInput: userAccelerometer error err=$err');
        }
      },
      cancelOnError: false,
    );
    _userMotionLive = true;

    _rawMotionSub = accelerometerEventStream().listen(
      _onRawMotion,
      onError: (Object err) {
        _rawMotionLive = false;
        if (LOGGING_SWITCH) {
          customlog('slamInput: accelerometer error err=$err');
        }
      },
      cancelOnError: false,
    );
    _rawMotionLive = true;

    if (LOGGING_SWITCH) {
      customlog('slamInput: motion streams started (user + raw fallback)');
    }
  }

  void _stopMotion() {
    unawaited(_userMotionSub?.cancel());
    unawaited(_rawMotionSub?.cancel());
    _userMotionSub = null;
    _rawMotionSub = null;
    _userMotionLive = false;
    _rawMotionLive = false;
  }

  void _emitCommit(SlamInputPayload payload) {
    if (LOGGING_SWITCH) {
      customlog(
        'slamInput: commit source=${payload.source} '
        'speed=${payload.speed.toStringAsFixed(2)} '
        'angle=${payload.trajectory.angleDeg.toStringAsFixed(1)} '
        'swipeDy=${_dragDy.toStringAsFixed(1)} '
        'peakMotion=${_peakMotion.toStringAsFixed(2)}',
      );
    }
    widget.onCommit(payload);
  }

  void _commitFromShake({
    required double motionPeakMagnitude,
    required double motionPeakX,
    required double motionPeakY,
    required double motionPeakZ,
    required String source,
  }) {
    if (!widget.armed || _committed) return;
    _committed = true;
    final payload = fuseMotionSlamInput(
      motionPeakMagnitude: motionPeakMagnitude,
      motionPeakX: motionPeakX,
      motionPeakY: motionPeakY,
      motionPeakZ: motionPeakZ,
    );
    _emitCommit(
      SlamInputPayload(
        speed: payload.speed,
        trajectory: payload.trajectory,
        source: source,
        swipe: payload.swipe,
        motion: payload.motion,
      ),
    );
  }

  void _tryCommitSwipe({
    required double primaryVelocity,
    required String source,
  }) {
    if (!widget.armed || _committed) return;
    if (_dragDy < widget.minDownSwipeDy) return;

    _committed = true;
    _emitCommit(
      fuseSlamInput(
        swipePrimaryVelocity: primaryVelocity,
        swipeDx: _dragDx,
        swipeDy: _dragDy,
        motionPeakMagnitude: _peakMotion,
        motionPeakX: _peakX,
        motionPeakY: _peakY,
        motionPeakZ: _peakZ,
        motionAvailable: _motionAvailable,
        source: source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        if (!widget.armed || _committed) return;
        if (details.delta.dy > 0) {
          _dragDx += details.delta.dx;
          _dragDy += details.delta.dy;
        }
      },
      onVerticalDragEnd: (details) {
        _tryCommitSwipe(
          primaryVelocity: details.primaryVelocity ?? 0,
          source: kIsWeb ? 'web_fallback' : 'gesture',
        );
      },
      child: widget.child,
    );
  }
}
