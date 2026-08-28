import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// How long to wait for at least one accelerometer sample at cold start.
const Duration kSlamShakeProbeTimeout = Duration(milliseconds: 600);

/// UI copy when shake may be used alongside swipe.
class SlamTurnHints {
  const SlamTurnHints({
    required this.primary,
    required this.secondary,
  });

  final String primary;
  final String secondary;
}

SlamTurnHints slamTurnHints({required bool shakeAvailable}) {
  if (shakeAvailable) {
    return const SlamTurnHints(
      primary: 'Your turn — swipe down or shake to slam',
      secondary: '5s timer — shake works without a swipe',
    );
  }
  return const SlamTurnHints(
    primary: 'Your turn — swipe down to slam',
    secondary: '5s timer',
  );
}

/// Whether this device can deliver motion samples for shake slams.
///
/// Official APIs:
/// - [sensors_plus](https://pub.dev/packages/sensors_plus): no availability
///   probe — subscribe and handle [Stream.onError]; missing sensors error out.
/// - Android: [PackageManager.FEATURE_SENSOR_ACCELEROMETER] or
///   `SensorManager.getDefaultSensor(TYPE_ACCELEROMETER) != null`.
/// - iOS: `CMMotionManager.isAccelerometerAvailable`.
///
/// Pure-Dart probe: if **either** user-accelerometer or raw accelerometer
/// delivers an event within [timeout], shake is treated as available (covers
/// OEMs that flatline user accel but expose raw accel). Web has no sensors.
Future<bool> probeSlamShakeAvailable({
  Duration timeout = kSlamShakeProbeTimeout,
}) async {
  if (kIsWeb) {
    if (LOGGING_SWITCH) {
      customlog('slamMotion: probe skipped (web → swipe only)');
    }
    return false;
  }

  var userOk = false;
  var rawOk = false;
  var userErr = false;
  var rawErr = false;

  StreamSubscription<UserAccelerometerEvent>? userSub;
  StreamSubscription<AccelerometerEvent>? rawSub;
  Timer? timer;

  final done = Completer<bool>();

  void finish(bool available) {
    if (done.isCompleted) return;
    done.complete(available);
  }

  void evaluate() {
    if (userOk || rawOk) {
      finish(true);
      return;
    }
    if (userErr && rawErr) {
      finish(false);
    }
  }

  userSub = userAccelerometerEventStream().listen(
    (_) {
      userOk = true;
      evaluate();
    },
    onError: (Object err) {
      userErr = true;
      if (LOGGING_SWITCH) {
        customlog('slamMotion: probe userAccelerometer error err=$err');
      }
      evaluate();
    },
    cancelOnError: false,
  );

  rawSub = accelerometerEventStream().listen(
    (_) {
      rawOk = true;
      evaluate();
    },
    onError: (Object err) {
      rawErr = true;
      if (LOGGING_SWITCH) {
        customlog('slamMotion: probe accelerometer error err=$err');
      }
      evaluate();
    },
    cancelOnError: false,
  );

  timer = Timer(timeout, () {
    finish(userOk || rawOk);
  });

  final available = await done.future;
  timer.cancel();
  await userSub.cancel();
  await rawSub.cancel();

  if (LOGGING_SWITCH) {
    customlog(
      'slamMotion: probe result available=$available '
      'userOk=$userOk rawOk=$rawOk userErr=$userErr rawErr=$rawErr',
    );
  }
  return available;
}
