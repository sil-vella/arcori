import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../utils/dev_logger.dart';
import '../../play/game_controls_prefs.dart';
import 'slam_input_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Minimum downward travel on the locked stack before a swipe commit.
const double kMinLockedSwipeDy = 40;

/// Accel XY → table meters per (m/s²) sample (coarse aim).
const double kAccelAimScale = 0.0032;

/// Ignore tiny XY noise when aiming with the phone.
const double kAccelAimDeadzone = 0.12;

/// Table-plane span (±) mapped from stack edges while aiming.
/// Wider than disc radius so the full stack pad stays usable for placement.
const double kTouchAimSpanMeters = kSlamAimHitRadius * 2.4;

/// Z must dominate XY so tilt does not count as a slam.
const double kShakeZDominance = 1.75;

typedef SlamInputCommitCallback = void Function(SlamInputPayload payload);
typedef SlamAimChangedCallback = void Function(SlamAim aim);
typedef SlamPowerPreviewCallback = void Function(double? power01);

/// Handle for stack gestures + aim lock while [SlamInputCapture] owns commit.
class SlamInputHandle {
  SlamInputHandle._(this._state);

  final _SlamInputCaptureState _state;

  bool get aimLocked => _state._aimLocked;

  void toggleAimLock() => _state.toggleAimLock();

  /// Unlocked touch: move hit marker anywhere on the stack.
  void onAimAtLocal(Offset local, Size areaSize) =>
      _state.onAimAtLocal(local, areaSize);

  /// Locked touch: entire stack tracks downward swipe for power.
  void onPowerDragUpdate(DragUpdateDetails details) =>
      _state.onPowerDragUpdate(details);

  void onPowerDragEnd(DragEndDetails details) =>
      _state.onPowerDragEnd(details);

  /// Lock hit marker (accel + touch).
  Widget aimLockButton({Key? key}) {
    return _SlamAimLockButton(
      key: key,
      locked: _state._aimLocked,
      enabled: _state.widget.armed && !_state._committed,
      onPressed: _state.toggleAimLock,
    );
  }
}

/// Captures exclusive accel OR touch slam input during an armed turn.
///
/// Both modes: aim → lock → commit (shake or stack swipe).
class SlamInputCapture extends StatefulWidget {
  const SlamInputCapture({
    super.key,
    required this.armed,
    required this.controlMode,
    required this.onCommit,
    required this.builder,
    this.onAimChanged,
    this.onPowerPreview,
    this.minLockedSwipeDy = kMinLockedSwipeDy,
    this.minShakeMps2 = kMinShakeMps2,
    this.minRawShakeDelta = kMinRawShakeDelta,
  });

  final bool armed;
  final SlamControlMode controlMode;
  final SlamInputCommitCallback onCommit;
  final SlamAimChangedCallback? onAimChanged;
  /// Live 0–1 while swiping/shaking, or frozen power right after commit.
  final SlamPowerPreviewCallback? onPowerPreview;
  final Widget Function(BuildContext context, SlamInputHandle handle) builder;
  final double minLockedSwipeDy;
  final double minShakeMps2;
  final double minRawShakeDelta;

  @override
  State<SlamInputCapture> createState() => _SlamInputCaptureState();
}

class _SlamInputCaptureState extends State<SlamInputCapture> {
  late final SlamInputHandle _handle = SlamInputHandle._(this);

  double _swipeDy = 0;
  double _peakZ = 0;
  SlamAim _aim = SlamAim.center;
  StreamSubscription<UserAccelerometerEvent>? _userMotionSub;
  StreamSubscription<AccelerometerEvent>? _rawMotionSub;
  bool _userMotionLive = false;
  bool _rawMotionLive = false;
  bool _userSamplesSeen = false;
  bool _committed = false;
  bool _aimLocked = false;

  bool get _accelMode => widget.controlMode == SlamControlMode.accel;
  bool get _touchMode => widget.controlMode == SlamControlMode.touch;

  @override
  void didUpdateWidget(covariant SlamInputCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.armed && !oldWidget.armed) {
      _resetSession(reason: 'armed');
      if (_accelMode) _startMotion();
      if (LOGGING_SWITCH) {
        customlog('slamInput: armed mode=${widget.controlMode.name}');
      }
    } else if (!widget.armed && oldWidget.armed) {
      if (LOGGING_SWITCH && !_committed) {
        customlog(
          'slamInput: disarmed without commit '
          'peakZ=${_peakZ.toStringAsFixed(2)} '
          'aim=(${_aim.x.toStringAsFixed(3)},${_aim.z.toStringAsFixed(3)}) '
          'mode=${widget.controlMode.name}',
        );
      }
      _stopMotion();
      _resetSession(reason: 'disarmed');
    } else if (widget.armed &&
        oldWidget.controlMode != widget.controlMode) {
      _stopMotion();
      _resetSession(reason: 'modeChange');
      if (_accelMode) _startMotion();
    }
  }

  @override
  void initState() {
    super.initState();
    // Local reset only — notifying parent here setStates an ancestor mid-mount
    // (! _dirty assertion under the match fullscreen shell).
    _resetSession(reason: 'init', notifyParent: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onAimChanged?.call(SlamAim.center);
      widget.onPowerPreview?.call(null);
    });
    if (widget.armed && _accelMode) {
      _startMotion();
    }
  }

  @override
  void dispose() {
    _stopMotion();
    super.dispose();
  }

  void _resetSession({
    required String reason,
    bool notifyParent = true,
  }) {
    _swipeDy = 0;
    _peakZ = 0;
    _aim = SlamAim.center;
    _committed = false;
    _aimLocked = false;
    _userSamplesSeen = false;
    if (LOGGING_SWITCH) {
      customlog('slamInput: resetAim reason=$reason → center');
    }
    if (!notifyParent) return;
    // Parent setState must not run while this element is mounting/updating.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onAimChanged?.call(_aim);
      widget.onPowerPreview?.call(null);
    });
  }

  void toggleAimLock() {
    if (!widget.armed || _committed) return;
    setState(() {
      _aimLocked = !_aimLocked;
      _swipeDy = 0;
    });
    if (!_aimLocked) {
      _previewPower(null);
    }
    if (LOGGING_SWITCH) {
      customlog(
        'slamInput: aimLock=${_aimLocked ? 'on' : 'off'} '
        'mode=${widget.controlMode.name} '
        'aim=(${_aim.x.toStringAsFixed(3)},${_aim.z.toStringAsFixed(3)})',
      );
    }
  }

  void _setAim(SlamAim next) {
    if (_aimLocked) return;
    final clamped = next.clampToTable();
    if ((clamped.x - _aim.x).abs() < 1e-6 &&
        (clamped.z - _aim.z).abs() < 1e-6) {
      return;
    }
    _aim = clamped;
    widget.onAimChanged?.call(_aim);
  }

  void _previewPower(double? power01) {
    widget.onPowerPreview?.call(power01?.clamp(0.0, 1.0));
  }

  /// Unlocked: finger position on stack maps absolutely to table aim (XZ).
  void onAimAtLocal(Offset local, Size areaSize) {
    if (!widget.armed || _committed || !_touchMode || _aimLocked) return;
    if (areaSize.width < 1 || areaSize.height < 1) return;
    final nx = ((local.dx / areaSize.width) * 2 - 1).clamp(-1.0, 1.0);
    final nz = -((local.dy / areaSize.height) * 2 - 1).clamp(-1.0, 1.0);
    _setAim(
      SlamAim(
        x: nx * kTouchAimSpanMeters,
        z: nz * kTouchAimSpanMeters,
      ),
    );
  }

  /// Locked: entire stack area tracks swipe power (downward), then commit.
  void onPowerDragUpdate(DragUpdateDetails details) {
    if (!widget.armed || _committed || !_touchMode || !_aimLocked) return;
    if (details.delta.dy <= 0) return;
    _swipeDy += details.delta.dy;
    final fromDist = (_swipeDy / swipeMaxDragDy).clamp(0.0, 1.0);
    _previewPower(fromDist);
  }

  void onPowerDragEnd(DragEndDetails details) {
    if (!widget.armed || _committed || !_touchMode || !_aimLocked) return;
    if (_swipeDy < widget.minLockedSwipeDy) {
      _swipeDy = 0;
      _previewPower(null);
      return;
    }
    final vy = details.primaryVelocity ?? 0;
    _committed = true;
    final frozen = _aim;
    final payload = fuseTouchPowerSlam(
      swipePrimaryVelocity: vy,
      swipeDy: _swipeDy,
      aim: frozen,
      source: kIsWeb ? 'web_fallback' : 'gesture',
    );
    _previewPower(payload.speed);
    _emitCommit(payload);
  }

  bool _zShakeDominates(double zMag, double x, double y) {
    final xy = max(x.abs(), y.abs());
    return zMag >= widget.minShakeMps2 && zMag >= xy * kShakeZDominance;
  }

  void _onUserMotion(UserAccelerometerEvent event) {
    if (!widget.armed || _committed || !_accelMode) return;
    _userSamplesSeen = true;

    // XY aims with deadzone — Z never moves the marker; lock freezes aim.
    final ax = event.x.abs() < kAccelAimDeadzone ? 0.0 : event.x;
    final ay = event.y.abs() < kAccelAimDeadzone ? 0.0 : event.y;
    if (ax != 0 || ay != 0) {
      _setAim(
        SlamAim(
          x: _aim.x + ax * kAccelAimScale,
          z: _aim.z + ay * kAccelAimScale,
        ),
      );
    }

    final zMag = event.z.abs();
    if (zMag > _peakZ) _peakZ = zMag;
    final preview = (zMag / motionMaxMps2).clamp(0.0, 1.0);
    if (zMag >= widget.minShakeMps2 * 0.45) {
      _previewPower(preview);
    }

    if (!_zShakeDominates(zMag, event.x, event.y)) return;

    _commitFromShake(
      motionPeakMagnitude: zMag,
      motionPeakX: event.x,
      motionPeakY: event.y,
      motionPeakZ: event.z,
      source: 'shake',
    );
  }

  void _onRawMotion(AccelerometerEvent event) {
    if (!widget.armed || _committed || !_accelMode) return;
    if (_userMotionLive && _userSamplesSeen) return;

    final ax = event.x.abs() < kAccelAimDeadzone ? 0.0 : event.x;
    final ay = event.y.abs() < kAccelAimDeadzone ? 0.0 : event.y;
    if (ax != 0 || ay != 0) {
      _setAim(
        SlamAim(
          x: _aim.x + ax * kAccelAimScale * 0.5,
          z: _aim.z + ay * kAccelAimScale * 0.5,
        ),
      );
    }

    final zDelta = (event.z - gravityMps2).abs();
    if (zDelta > _peakZ) _peakZ = zDelta;
    if (zDelta >= widget.minRawShakeDelta * 0.45) {
      _previewPower((zDelta / motionMaxMps2).clamp(0.0, 1.0));
    }

    final xy = max(event.x.abs(), event.y.abs());
    if (zDelta < widget.minRawShakeDelta ||
        zDelta < xy * kShakeZDominance) {
      return;
    }

    _commitFromShake(
      motionPeakMagnitude: zDelta.clamp(0.0, motionMaxMps2),
      motionPeakX: event.x,
      motionPeakY: event.y,
      motionPeakZ: event.z,
      source: 'shake_raw',
    );
  }

  void _startMotion() {
    if (kIsWeb || !_accelMode) return;

    _userMotionSub?.cancel();
    _rawMotionSub?.cancel();
    _userMotionLive = false;
    _rawMotionLive = false;
    _userSamplesSeen = false;

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
      customlog(
        'slamInput: accel streams started '
        'user=$_userMotionLive raw=$_rawMotionLive '
        'minZ=${widget.minShakeMps2}',
      );
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
        'aim=(${payload.aim.x.toStringAsFixed(3)},'
        '${payload.aim.z.toStringAsFixed(3)}) '
        'mode=${widget.controlMode.name} '
        'locked=$_aimLocked '
        'swipeDy=${_swipeDy.toStringAsFixed(1)} '
        'peakZ=${_peakZ.toStringAsFixed(2)}',
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
    if (!widget.armed || _committed || !_accelMode) return;
    _committed = true;
    final frozen = _aim;
    final payload = fuseAccelPowerSlam(
      motionPeakMagnitude: motionPeakMagnitude,
      motionPeakX: motionPeakX,
      motionPeakY: motionPeakY,
      motionPeakZ: motionPeakZ,
      aim: frozen,
      source: source,
    );
    _previewPower(payload.speed);
    _emitCommit(payload);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _handle);
}

class _SlamAimLockButton extends StatelessWidget {
  const _SlamAimLockButton({
    super.key,
    required this.locked,
    required this.enabled,
    required this.onPressed,
  });

  final bool locked;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 220,
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !enabled
                    ? Colors.white12
                    : (locked ? Colors.lightGreenAccent : Colors.white38),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  locked ? Icons.lock : Icons.lock_open,
                  color: !enabled
                      ? Colors.white24
                      : (locked ? Colors.lightGreenAccent : Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  locked ? 'LOCKED' : 'LOCK',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: !enabled
                            ? Colors.white24
                            : (locked
                                ? Colors.lightGreenAccent
                                : Colors.white70),
                      ),
                ),
                if (locked) ...[
                  const SizedBox(height: 4),
                  Text(
                    'AIM',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.lightGreenAccent.withValues(alpha: 0.8),
                          fontSize: 10,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal 0–1 power readout (place above the stack).
///
/// Reserves space from match start; animates whenever [power01] changes
/// (local charge/commit or any seat’s authority slam).
class SlamPowerGauge extends StatefulWidget {
  const SlamPowerGauge({
    super.key,
    required this.power01,
    this.label = 'Power',
  });

  final double power01;
  final String label;

  @override
  State<SlamPowerGauge> createState() => _SlamPowerGaugeState();
}

class _SlamPowerGaugeState extends State<SlamPowerGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animation = AlwaysStoppedAnimation(widget.power01.clamp(0.0, 1.0));
  }

  @override
  void didUpdateWidget(covariant SlamPowerGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.power01.clamp(0.0, 1.0);
    final prev = oldWidget.power01.clamp(0.0, 1.0);
    if ((prev - next).abs() < 1e-4) return;
    _animation = Tween<double>(begin: prev, end: next).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final p = _animation.value.clamp(0.0, 1.0);
        final pct = (p * 100).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                Text('$pct%', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 10,
                backgroundColor: Colors.white12,
                color: p < 0.35
                    ? Colors.lightGreenAccent
                    : (p < 0.7 ? Colors.amberAccent : Colors.orangeAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  String get label => widget.label;
}
