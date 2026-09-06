/// Pure-Dart 3D thin-cylinder slam sim — authoritative xyzq pose timeline.
library;

import 'dart:math';

import 'package:vector_math/vector_math.dart';

import '../../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const double kSlamPhysicsDt = 1.0 / 60.0;
const int kSlamPhysicsSampleEvery = 2;
/// Shorter budget — soft settle + snap blend should finish well under this.
const int kSlamPhysicsMaxSteps = 84;
/// After this step, damp hard so quiet-exit can fire.
const int kSlamPhysicsSoftSettleAt = 48;
/// Multi-frame orientation/height blend to flat (avoids abrupt last-frame snap).
const int kSlamPhysicsSnapBlendSteps = 28;
/// ~50mm diameter draws near the 72px disc widget.
const double kSlamPhysicsPxPerMeter = 1440.0;
const String kSlamPhysicsSpace = 'xyzq';
/// Very slight kick falloff per disc below the top (top=1.00, next=0.95, …).
const double kStackDepthKickFade = 0.05;

/// Real-ish Arcori puck: Ø50mm × 3mm thick.
const double kDiscRadius = 0.025;
const double kDiscHalfHeight = 0.0015;
const double kStackGap = 0.0002;
const double kDiscFriction = 0.62;
/// Near-inelastic — less rebound chatter / bounce loops.
const double kDiscRestitution = 0.015;
/// Heavier puck — collision response softer; kicks still set ω/v directly.
const double kDiscMass = 2.8;
/// Balanced feel (matches Dart `kDefaultSlamFeelProfile` / `slamFeelBalanced`).
const double kLinearKickScale = 0.85;
const double kAngularKickScale = 1.65;
const double kTipMul = 2.55;
const double kPunchThroughPower = 0.25;
const double kSleepLin = 0.055;
const double kSleepAng = 0.28;
/// Past the equator (±deadzone) snaps to a face; edges stay upright.
const double kFaceUpDot = 0.03;
/// Soft-miss / no-kick floor — only near-zero (timeout) is a hard miss.
const double kSlamMinPower = 0.005;
const double kWallLimit = 0.45;
const int kSolverIters = 12;
const double kBaumgarte = 0.08;
const double kSlop = 0.0002;
const double kLinearDamping = 0.88;
const double kAngularDamping = 0.48;
/// Softens low power more than high.
const double kPowerKickExponent = 1.05;
/// Below this, kicks taper further so near-zero rarely flips.
const double kWeakKickFloor = 0.06;
/// Allow strong slams to travel farther in XYZ before clamp.
const double kMaxLinSpeed = 1.7;
const double kMaxAngSpeed = 11.0;
const double kWallRestitution = 0.04;
/// Quiet frames required before early exit.
const int kSettledQuietSteps = 4;
const int kMinStepsBeforeQuiet = 16;

class SlamPhysicsResult {
  const SlamPhysicsResult({
    required this.pieces,
    required this.flippedPieceIds,
    required this.scoreDeltas,
    required this.sim,
  });

  final List<Map<String, dynamic>> pieces;
  final List<String> flippedPieceIds;
  final Map<String, int> scoreDeltas;
  final Map<String, dynamic> sim;
}

/// Face-up when local +Y (face normal) points mostly toward world +Y.
bool isFaceUpOrientation(Quaternion q) {
  final up = q.rotated(Vector3(0, 1, 0));
  return up.y >= kFaceUpDot;
}

/// Identity = face-up (local Y → world Y). π about X = face-down.
Quaternion faceOrientation({required bool faceUp}) {
  if (faceUp) return Quaternion.identity();
  return Quaternion.axisAngle(Vector3(1, 0, 0), pi);
}

/// Flatten [q] onto the table while keeping in-plane spin (yaw around world +Y).
Quaternion restingOrientationFrom(Quaternion q, {required bool faceUp}) {
  final localX = q.rotated(Vector3(1, 0, 0));
  var hx = localX.x;
  var hz = localX.z;
  var hLen = sqrt(hx * hx + hz * hz);
  if (hLen < 1e-5) {
    final localZ = q.rotated(Vector3(0, 0, 1));
    hx = localZ.x;
    hz = localZ.z;
    hLen = sqrt(hx * hx + hz * hz);
  }
  final yaw = hLen < 1e-5 ? 0.0 : atan2(-hz, hx);
  final yawQ = Quaternion.axisAngle(Vector3(0, 1, 0), yaw);
  if (faceUp) {
    yawQ.normalize();
    return yawQ;
  }
  final down = yawQ * Quaternion.axisAngle(Vector3(1, 0, 0), pi);
  down.normalize();
  return down;
}

/// Face normal is world ±Y (lying on the table, not on edge).
bool isFlatOnTable(Quaternion q, {double eps = 0.02}) {
  final n = q.rotated(Vector3(0, 1, 0));
  return (n.y.abs() - 1.0).abs() <= eps && n.x.abs() <= eps && n.z.abs() <= eps;
}

/// Run fixed-timestep 3D sim; thin discs collide and tumble to resting faces.
SlamPhysicsResult runSlamPhysics({
  required List<Map<String, dynamic>> pieces,
  required double dx,
  required double dy,
  required double speed,
  required double power,
  required int maxAffect,
  required Random rng,
  int spreadAttr = 5,
}) {
  if (LOGGING_SWITCH) {
    customlog(
      'slamPhysics: start pieces=${pieces.length} power=${power.toStringAsFixed(3)} '
      'speed=${speed.toStringAsFixed(3)} dx=${dx.toStringAsFixed(3)} '
      'dy=${dy.toStringAsFixed(3)} maxAffect=$maxAffect feel=balanced '
      'space=$kSlamPhysicsSpace',
    );
  }

  final sorted = List<Map<String, dynamic>>.from(pieces)
    ..sort((a, b) {
      final sa = a['stackIndex'] is int ? a['stackIndex'] as int : 0;
      final sb = b['stackIndex'] is int ? b['stackIndex'] as int : 0;
      return sa.compareTo(sb);
    });

  final bodies = <_Body3>[];
  final ids = <String>[];
  final wasFaceUp = <bool>[];

  for (var i = 0; i < sorted.length; i++) {
    final p = sorted[i];
    final id = p['pieceId']?.toString() ?? 'p$i';
    final faceUp = p['faceUp'] == true;
    final y = kDiscHalfHeight + i * (2 * kDiscHalfHeight + kStackGap);
    bodies.add(
      _Body3(
        position: Vector3(0, y, 0),
        orientation: faceOrientation(faceUp: faceUp),
        mass: kDiscMass,
        radius: kDiscRadius,
        halfHeight: kDiscHalfHeight,
      ),
    );
    ids.add(id);
    wasFaceUp.add(faceUp);
  }

  final punchedThrough = <int>{};
  final kickedFaceDown = <int>{};
  // 0..1 how far above mid power — drives flip energy, XYZ travel, chaos.
  final strong =
      power < 0.45 ? 0.0 : ((power - 0.45) / 0.55).clamp(0.0, 1.0);
  if (power >= kSlamMinPower && bodies.isNotEmpty) {
    final len = sqrt(dx * dx + dy * dy);
    final ndx = len > 1e-6 ? dx / len : 0.0;
    // Table-plane slam: lateral + depth dominate; light into-stack component.
    final into = len > 1e-6 ? dy.abs() / len : 1.0;
    var vx = ndx * 0.55 + (ndx.abs() < 0.2 ? 0.35 : 0.0);
    var vy = -into * 0.22;
    var vz = -0.95 * into;
    final vLen = sqrt(vx * vx + vy * vy + vz * vz);
    if (vLen > 1e-6) {
      vx /= vLen;
      vy /= vLen;
      vz /= vLen;
    }
    // Unit lateral (perpendicular in XZ) for fan-out spread.
    var latX = -vz;
    var latZ = vx;
    final latLen = sqrt(latX * latX + latZ * latZ);
    if (latLen > 1e-6) {
      latX /= latLen;
      latZ /= latLen;
    } else {
      latX = 1.0;
      latZ = 0.0;
    }
    final spreadMul = (spreadAttr.clamp(1, 10)) / 5.0;
    final powerForKick =
        power < kWeakKickFloor ? power * (power / kWeakKickFloor) : power;
    final powerCurve = pow(powerForKick, kPowerKickExponent).toDouble();
    // Strong hits punch above the curve — more XYZ travel + flip chance.
    final strongBoost = 1.0 + strong * 0.85;
    final kickLin = powerCurve * kLinearKickScale * strongBoost;
    final kickAng = powerCurve * kAngularKickScale * (1.0 + strong * 1.55);
    // Every face-down disc gets a direct kick; only a hair weaker further down.

    // Slight aim yaw chaos grows with power (unpredictability, not wild).
    final yawJitter = (rng.nextDouble() - 0.5) * 0.28 * (0.2 + strong * 1.4);
    final cosY = cos(yawJitter);
    final sinY = sin(yawJitter);
    final rvx = vx * cosY - vz * sinY;
    final rvz = vx * sinY + vz * cosY;

    var affected = 0;
    for (var i = bodies.length - 1; i >= 0; i--) {
      final fromTop = bodies.length - 1 - i;
      final depthFade =
          (1.0 - fromTop * kStackDepthKickFade).clamp(0.82, 1.0);
      if (wasFaceUp[i]) {
        // Shove face-up discs aside so face-down below can tip (punch-through).
        if (power >= kPunchThroughPower) {
          final clear = kickLin * (0.95 + 0.5 * speed) * spreadMul;
          final fan = (rng.nextDouble() - 0.5) * (2.8 + strong * 1.6) * spreadMul;
          bodies[i].linearVelocity.add(
            Vector3(
              (rvx + latX * fan) * clear * 2.15,
              (0.22 + strong * 0.35) * clear,
              (rvz + latZ * fan) * clear * 2.05,
            ),
          );
        }
        continue;
      }
      // Unpredictability rises with power (was inverted before).
      final chaos = 0.22 + strong * 0.95;
      final jitterX = (rng.nextDouble() - 0.5) * chaos;
      final jitterZ = (rng.nextDouble() - 0.5) * chaos;
      final jitterY = (rng.nextDouble() - 0.15) * (0.12 + strong * 0.55);
      // Wide alternating fan — separate discs so collisions die sooner.
      final fan =
          ((affected % 2 == 0) ? 1.0 : -1.0) *
          (1.05 + fromTop * 0.55 + rng.nextDouble() * (0.95 + strong * 0.7)) *
          spreadMul *
          (0.9 + power + strong * 0.45);
      final scale =
          kickLin * (1.2 + 0.55 * speed + strong * 0.5) * depthFade;
      // Hop off the table so tip spin isn't crushed by ground contacts.
      final hop =
          (0.22 + strong * 0.9 + rng.nextDouble() * (0.12 + strong * 0.4)) *
              depthFade;
      bodies[i].position.y += 0.0015 + strong * 0.006;
      bodies[i].linearVelocity.add(
        Vector3(
          (rvx + latX * fan + jitterX) * scale,
          (vy * (0.85 + strong * 0.55) + jitterY + hop) * scale * 0.55,
          (rvz + latZ * fan + jitterZ) * scale,
        ),
      );
      // Roll around table-plane axis ⟂ slam (pog flip in the hit direction) + yaw.
      final spinSign = rng.nextBool() ? 1.0 : -1.0;
      var ang = kickAng * (1.25 + 0.65 * speed + strong * 1.35) * depthFade;
      final hasUpAbove = wasFaceUp.sublist(i + 1).any((u) => u);
      if (hasUpAbove) {
        ang *= 1.25;
        punchedThrough.add(i);
      }
      final tip = spinSign * ang * kTipMul;
      final tipYaw = (rng.nextDouble() * 2 - 1) * ang * (0.45 + strong * 0.55);
      final tipTwist = (rng.nextDouble() - 0.5) * ang * (0.18 + strong * 0.35);
      bodies[i].angularVelocity.add(
        Vector3(
          latX * tip + rvx * tipTwist,
          tipYaw,
          latZ * tip + rvz * tipTwist,
        ),
      );
      kickedFaceDown.add(i);
      if (hasUpAbove) {
        bodies[i].linearVelocity.add(
          Vector3(
            rvx * kickLin * 0.5,
            -kickLin * (0.12 + strong * 0.1),
            rvz * kickLin * 0.45,
          ),
        );
      }
      affected++;
    }

    if (affected == 0) {
      final top = bodies.length - 1;
      final scale = kickLin * (1.15 + strong * 0.4) * spreadMul;
      final fan = (rng.nextDouble() - 0.5) * (2.2 + strong * 1.2) * spreadMul;
      bodies[top].linearVelocity.add(
        Vector3(
          (rvx + latX * fan) * scale,
          vy * scale * (0.85 + strong * 0.4),
          (rvz + latZ * fan) * scale,
        ),
      );
      final tip = kickAng * (0.9 + strong * 0.7);
      final yaw = kickAng * (0.4 + strong * 0.5) * (rng.nextBool() ? 1.0 : -1.0);
      bodies[top].angularVelocity.add(
        Vector3(latX * tip, yaw, latZ * tip),
      );
      if (LOGGING_SWITCH) {
        customlog(
          'slamPhysics: punchThroughKick top=${ids[top]} '
          'kickLin=${kickLin.toStringAsFixed(2)}',
        );
      }
    } else if (LOGGING_SWITCH) {
      customlog(
        'slamPhysics: kicked faceDown=$affected kickLin=${kickLin.toStringAsFixed(2)} '
        'kickAng=${kickAng.toStringAsFixed(2)} spreadMul=${spreadMul.toStringAsFixed(2)} '
        'strong=${strong.toStringAsFixed(2)}',
      );
    }
  }

  List<List<dynamic>> samplePoses() {
    final poses = <List<dynamic>>[];
    for (var i = 0; i < bodies.length; i++) {
      final b = bodies[i];
      final q = b.orientation;
      poses.add([
        ids[i],
        _round4(b.position.x),
        _round4(b.position.y),
        _round4(b.position.z),
        _round4(q.x),
        _round4(q.y),
        _round4(q.z),
        _round4(q.w),
      ]);
    }
    return poses;
  }

  final frames = <Map<String, dynamic>>[
    {'i': 0, 'p': samplePoses()},
  ];

  var settledSteps = 0;
  var stepsRun = 0;
  // Strong hits need longer free tumble; weak taps quiet before they creep over.
  final softAt = power < 0.22
      ? 20
      : (strong > 0.45
          ? kSlamPhysicsSoftSettleAt + 18
          : kSlamPhysicsSoftSettleAt);
  final softAngKill = power < 0.22
      ? 0.7
      : (strong > 0.45 ? 0.97 : 0.93);
  final softLinKill = strong > 0.45 ? 0.88 : 0.78;
  // Free tumble first; flatten only as they come down so flips read in the air.
  final flattenStart = power < 0.22 ? 18 : 38;
  for (var step = 1; step <= kSlamPhysicsMaxSteps; step++) {
    if (step >= softAt) {
      for (final b in bodies) {
        b.linearVelocity.scale(softLinKill);
        b.angularVelocity.scale(softAngKill);
        if (b.position.y > kDiscHalfHeight) {
          b.position.y += (kDiscHalfHeight - b.position.y) * 0.2;
        }
      }
    }
    _stepWorld(
      bodies,
      flattenPull: step < flattenStart
          ? 0.0
          : ((step - flattenStart) / 22).clamp(0.0, 1.0),
    );
    stepsRun = step;
    if (step % kSlamPhysicsSampleEvery == 0) {
      frames.add({'i': step, 'p': samplePoses()});
    }
    var allQuiet = true;
    for (final b in bodies) {
      final tip2 = b.angularVelocity.x * b.angularVelocity.x +
          b.angularVelocity.z * b.angularVelocity.z;
      if (b.linearVelocity.length2 > kSleepLin * kSleepLin ||
          tip2 > kSleepAng * kSleepAng) {
        allQuiet = false;
        break;
      }
    }
    if (allQuiet && step >= kMinStepsBeforeQuiet) {
      settledSteps++;
      if (settledSteps >= kSettledQuietSteps) break;
    } else {
      settledSteps = 0;
    }
  }

  // Capture pre-snap poses, then blend to flat faces over several frames.
  final fromQ = <Quaternion>[
    for (final b in bodies) Quaternion.copy(b.orientation),
  ];
  final fromP = <Vector3>[
    for (final b in bodies) b.position.clone(),
  ];
  for (final b in bodies) {
    b.linearVelocity.setValues(0, 0, 0);
    b.angularVelocity.setValues(0, 0, 0);
  }

  final targetQ = <Quaternion>[];
  for (var i = 0; i < bodies.length; i++) {
    final ny = fromQ[i].rotated(Vector3(0, 1, 0)).y;
    var faceUp = ny >= kFaceUpDot;
    if (power >= 0.4 && punchedThrough.contains(i)) {
      faceUp = true;
    }
    // Strong kicks: ground contacts often kill tip mid-flight — bias flip
    // chance up with power (slight unpredictability, not a wipe guarantee).
    if (!faceUp &&
        !wasFaceUp[i] &&
        kickedFaceDown.contains(i) &&
        strong >= 0.35) {
      final tipProgress = ((ny + 1.0) * 0.5).clamp(0.0, 1.0);
      final pFlip =
          (0.42 + strong * 0.48 + tipProgress * 0.2).clamp(0.0, 0.96);
      if (rng.nextDouble() < pFlip) {
        faceUp = true;
      }
    }
    if (wasFaceUp[i]) {
      faceUp = true;
    }
    targetQ.add(restingOrientationFrom(fromQ[i], faceUp: faceUp));
  }

  final blendStart = stepsRun;
  for (var s = 1; s <= kSlamPhysicsSnapBlendSteps; s++) {
    final t = s / kSlamPhysicsSnapBlendSteps;
    final u = t * t * (3.0 - 2.0 * t); // smoothstep
    for (var i = 0; i < bodies.length; i++) {
      bodies[i].orientation = _nlerpQuat(fromQ[i], targetQ[i], u);
      bodies[i].position.x = fromP[i].x;
      bodies[i].position.z = fromP[i].z;
      bodies[i].position.y =
          fromP[i].y + (kDiscHalfHeight - fromP[i].y) * u;
    }
    stepsRun = blendStart + s;
    if (s % kSlamPhysicsSampleEvery == 0 || s == kSlamPhysicsSnapBlendSteps) {
      frames.add({'i': stepsRun, 'p': samplePoses()});
    }
  }
  for (var i = 0; i < bodies.length; i++) {
    bodies[i].orientation = targetQ[i];
    bodies[i].position.y = kDiscHalfHeight;
  }
  if (frames.isNotEmpty) {
    frames[frames.length - 1] = {'i': stepsRun, 'p': samplePoses()};
  }

  final flipped = <String>[];
  final scoreDeltas = <String, int>{};
  final nextPieces = <Map<String, dynamic>>[];

  for (var i = 0; i < sorted.length; i++) {
    final prev = Map<String, dynamic>.from(sorted[i]);
    final id = ids[i];
    // Score only settled face normal — not cumulative tumble.
    final faceUp = isFaceUpOrientation(bodies[i].orientation);
    if (!wasFaceUp[i] && faceUp) {
      flipped.add(id);
      final owner = prev['ownerUserId']?.toString() ?? '';
      if (owner.isNotEmpty) {
        scoreDeltas[owner] = (scoreDeltas[owner] ?? 0) + 1;
      }
    }
    final finalFace = wasFaceUp[i] || faceUp;
    nextPieces.add({...prev, 'faceUp': finalFace});
  }

  if (LOGGING_SWITCH) {
    final faceSummary = [
      for (var i = 0; i < ids.length; i++)
        '${ids[i]}:ny=${bodies[i].orientation.rotated(Vector3(0, 1, 0)).y.toStringAsFixed(2)}',
    ].join(',');
    customlog(
      'slamPhysics: done steps=$stepsRun frames=${frames.length} '
      'flipped=$flipped faces=[$faceSummary]',
    );
  }

  return SlamPhysicsResult(
    pieces: nextPieces,
    flippedPieceIds: flipped,
    scoreDeltas: scoreDeltas,
    sim: {
      'dt': kSlamPhysicsDt,
      'sampleEvery': kSlamPhysicsSampleEvery,
      'pxPerMeter': kSlamPhysicsPxPerMeter,
      'space': kSlamPhysicsSpace,
      'steps': stepsRun,
      'frames': frames,
    },
  );
}

void _stepWorld(
  List<_Body3> bodies, {
  double flattenPull = 0,
}) {
  const dt = kSlamPhysicsDt;
  final gravity = Vector3(0, -10, 0);

  for (final b in bodies) {
    b.linearVelocity.add(gravity * dt);
    b.linearVelocity.scale(1.0 - kLinearDamping * dt);
    b.angularVelocity.scale(1.0 - kAngularDamping * dt);
    _clampVel(b);
    b.position.add(b.linearVelocity * dt);
    _integrateOrientation(b.orientation, b.angularVelocity, dt);
    _assistFaceSettle(b, flattenPull: flattenPull);
  }

  final contacts = <_Contact>[];
  for (final b in bodies) {
    _contactsBodyPlane(b, contacts);
    _contactsBodyWalls(b, contacts);
  }
  for (var i = 0; i < bodies.length; i++) {
    for (var j = i + 1; j < bodies.length; j++) {
      _contactsBodyBody(bodies[i], bodies[j], contacts);
    }
  }

  for (var iter = 0; iter < kSolverIters; iter++) {
    for (final c in contacts) {
      _resolveContact(c);
    }
  }
  for (final b in bodies) {
    _clampVel(b);
  }
}

void _clampVel(_Body3 b) {
  final lin = b.linearVelocity.length;
  if (lin > kMaxLinSpeed) {
    b.linearVelocity.scale(kMaxLinSpeed / lin);
  }
  final ang = b.angularVelocity.length;
  if (ang > kMaxAngSpeed) {
    b.angularVelocity.scale(kMaxAngSpeed / ang);
  }
}

void _integrateOrientation(Quaternion q, Vector3 omega, double dt) {
  final half = 0.5 * dt;
  final ow = Quaternion(omega.x * half, omega.y * half, omega.z * half, 0);
  final dq = ow * q;
  q.setValues(q.x + dq.x, q.y + dq.y, q.z + dq.z, q.w + dq.w);
  q.normalize();
}

void _contactsBodyPlane(_Body3 b, List<_Contact> out) {
  // Ground plane y = 0, normal +Y.
  final n = Vector3(0, 1, 0);
  final support = b.support(-n);
  final pen = -support.y;
  if (pen > 0) {
    out.add(
      _Contact(
        a: b,
        b: null,
        normal: n.clone(),
        point: Vector3(support.x, 0, support.z),
        penetration: pen,
        friction: kDiscFriction,
        restitution: kDiscRestitution,
      ),
    );
  }
}

void _contactsBodyWalls(_Body3 b, List<_Contact> out) {
  final r = b.radius;
  if (b.position.x - r < -kWallLimit) {
    final pen = -kWallLimit - (b.position.x - r);
    out.add(
      _Contact(
        a: b,
        b: null,
        normal: Vector3(1, 0, 0),
        point: Vector3(-kWallLimit, b.position.y, b.position.z),
        penetration: pen,
        friction: 0.35,
        restitution: kWallRestitution,
      ),
    );
  } else if (b.position.x + r > kWallLimit) {
    final pen = (b.position.x + r) - kWallLimit;
    out.add(
      _Contact(
        a: b,
        b: null,
        normal: Vector3(-1, 0, 0),
        point: Vector3(kWallLimit, b.position.y, b.position.z),
        penetration: pen,
        friction: 0.35,
        restitution: kWallRestitution,
      ),
    );
  }
  if (b.position.z - r < -kWallLimit) {
    final pen = -kWallLimit - (b.position.z - r);
    out.add(
      _Contact(
        a: b,
        b: null,
        normal: Vector3(0, 0, 1),
        point: Vector3(b.position.x, b.position.y, -kWallLimit),
        penetration: pen,
        friction: 0.35,
        restitution: kWallRestitution,
      ),
    );
  } else if (b.position.z + r > kWallLimit) {
    final pen = (b.position.z + r) - kWallLimit;
    out.add(
      _Contact(
        a: b,
        b: null,
        normal: Vector3(0, 0, -1),
        point: Vector3(b.position.x, b.position.y, kWallLimit),
        penetration: pen,
        friction: 0.35,
        restitution: kWallRestitution,
      ),
    );
  }
}

void _contactsBodyBody(_Body3 a, _Body3 b, List<_Contact> out) {
  // OBB–OBB via SAT (thin box extents = radius, halfHeight, radius).
  final axes = <Vector3>[];
  final aAxes = a.axes();
  final bAxes = b.axes();
  axes.addAll(aAxes);
  axes.addAll(bAxes);
  for (final aa in aAxes) {
    for (final ba in bAxes) {
      final c = aa.cross(ba);
      if (c.length2 > 1e-10) {
        c.normalize();
        axes.add(c);
      }
    }
  }

  var minPen = double.infinity;
  Vector3? bestAxis;
  for (final axis in axes) {
    final n = axis.normalized();
    final amin = a.support(-n);
    final amax = a.support(n);
    final bmin = b.support(-n);
    final bmax = b.support(n);
    final aProjMin = amin.dot(n);
    final aProjMax = amax.dot(n);
    final bProjMin = bmin.dot(n);
    final bProjMax = bmax.dot(n);
    final overlap = min(aProjMax, bProjMax) - max(aProjMin, bProjMin);
    if (overlap <= 0) return;
    if (overlap < minPen) {
      minPen = overlap;
      // Orient normal from a → b.
      final centerDelta = b.position - a.position;
      bestAxis = centerDelta.dot(n) >= 0 ? n : -n;
    }
  }
  if (bestAxis == null || minPen == double.infinity) return;

  final n = bestAxis;
  final point = (a.support(n) + b.support(-n)) * 0.5;
  out.add(
    _Contact(
      a: a,
      b: b,
      normal: n.clone(),
      point: point,
      penetration: minPen,
      friction: kDiscFriction,
      restitution: kDiscRestitution,
    ),
  );
}

void _resolveContact(_Contact c) {
  final a = c.a;
  final b = c.b;
  final n = c.normal;
  final ra = c.point - a.position;
  final rb = b == null ? Vector3.zero() : c.point - b.position;

  Vector3 velAt(Vector3 lin, Vector3 ang, Vector3 r) => lin + ang.cross(r);

  final va = velAt(a.linearVelocity, a.angularVelocity, ra);
  final vb = b == null
      ? Vector3.zero()
      : velAt(b.linearVelocity, b.angularVelocity, rb);
  final rv = va - vb;
  final vn = rv.dot(n);

  final e = c.restitution;
  // Effective inv mass.
  var invMassSum = a.invMass;
  if (b != null) invMassSum += b.invMass;

  final raXn = ra.cross(n);
  final rbXn = rb.cross(n);
  invMassSum += a.angularImpulseResponse(raXn);
  if (b != null) invMassSum += b.angularImpulseResponse(rbXn);
  if (invMassSum < 1e-12) return;

  var jn = 0.0;
  if (vn < 0) {
    jn = -(1 + e) * vn / invMassSum;
  }

  // Baumgarte position bias.
  final bias = max(0.0, c.penetration - kSlop) * kBaumgarte / kSlamPhysicsDt;
  jn += bias / invMassSum;
  if (jn < 0) jn = 0;

  final impulseN = n * jn;
  a.applyImpulse(impulseN, ra);
  b?.applyImpulse(-impulseN, rb);

  // Coulomb friction.
  final vt = rv - n * rv.dot(n);
  final vtLen = vt.length;
  if (vtLen > 1e-6) {
    final t = vt / vtLen;
    var invT = a.invMass;
    if (b != null) invT += b.invMass;
    final raXt = ra.cross(t);
    final rbXt = rb.cross(t);
    invT += a.angularImpulseResponse(raXt);
    if (b != null) invT += b.angularImpulseResponse(rbXt);
    if (invT > 1e-12) {
      var jt = -vt.dot(t) / invT;
      final maxF = c.friction * jn;
      jt = jt.clamp(-maxF, maxF);
      final impulseT = t * jt;
      a.applyImpulse(impulseT, ra);
      b?.applyImpulse(-impulseT, rb);
    }
  }
}

class _Body3 {
  _Body3({
    required this.position,
    required this.orientation,
    required this.mass,
    required this.radius,
    required this.halfHeight,
  })  : invMass = mass > 0 ? 1.0 / mass : 0.0,
        linearVelocity = Vector3.zero(),
        angularVelocity = Vector3.zero() {
    // Cylinder inertia about CM (axis = local Y).
    final h = 2 * halfHeight;
    final r2 = radius * radius;
    final ixx = (1.0 / 12.0) * mass * (3 * r2 + h * h);
    final iyy = 0.5 * mass * r2;
    invInertiaLocal = Vector3(
      ixx > 0 ? 1.0 / ixx : 0.0,
      iyy > 0 ? 1.0 / iyy : 0.0,
      ixx > 0 ? 1.0 / ixx : 0.0,
    );
  }

  Vector3 position;
  Quaternion orientation;
  Vector3 linearVelocity;
  Vector3 angularVelocity;
  final double mass;
  final double invMass;
  late final Vector3 invInertiaLocal;
  final double radius;
  final double halfHeight;

  List<Vector3> axes() {
    return [
      orientation.rotated(Vector3(1, 0, 0)),
      orientation.rotated(Vector3(0, 1, 0)),
      orientation.rotated(Vector3(0, 0, 1)),
    ];
  }

  Vector3 support(Vector3 dir) {
    final local = orientation.conjugated().rotated(dir);
    final sx = local.x >= 0 ? radius : -radius;
    final sy = local.y >= 0 ? halfHeight : -halfHeight;
    final sz = local.z >= 0 ? radius : -radius;
    // Prefer circular rim in XZ for a closer cylinder support.
    final radial = Vector3(local.x, 0, local.z);
    Vector3 localSupport;
    if (radial.length2 > 1e-12) {
      radial.normalize();
      localSupport = Vector3(radial.x * radius, sy, radial.z * radius);
    } else {
      localSupport = Vector3(sx, sy, sz);
    }
    return position + orientation.rotated(localSupport);
  }

  double angularImpulseResponse(Vector3 torqueAxis) {
    final local = orientation.conjugated().rotated(torqueAxis);
    final w = Vector3(
      local.x * invInertiaLocal.x,
      local.y * invInertiaLocal.y,
      local.z * invInertiaLocal.z,
    );
    final world = orientation.rotated(w);
    return world.dot(torqueAxis);
  }

  void applyImpulse(Vector3 impulse, Vector3 r) {
    linearVelocity.add(impulse * invMass);
    final torque = r.cross(impulse);
    final local = orientation.conjugated().rotated(torque);
    final wLocal = Vector3(
      local.x * invInertiaLocal.x,
      local.y * invInertiaLocal.y,
      local.z * invInertiaLocal.z,
    );
    angularVelocity.add(orientation.rotated(wLocal));
  }
}

class _Contact {
  _Contact({
    required this.a,
    required this.b,
    required this.normal,
    required this.point,
    required this.penetration,
    required this.friction,
    required this.restitution,
  });

  final _Body3 a;
  final _Body3? b;
  final Vector3 normal;
  final Vector3 point;
  final double penetration;
  final double friction;
  final double restitution;
}

double _round4(double v) => (v * 10000).roundToDouble() / 10000;

/// Pull off the rim toward the nearer face; damp leftover tip once nearly flat.
/// Keep in-plane spin (yaw). Do not inject a world-X tip (that stands on edge).
void _assistFaceSettle(_Body3 b, {double flattenPull = 0}) {
  final n = b.orientation.rotated(Vector3(0, 1, 0));
  final ny = n.y;
  if (flattenPull > 0 && ny.abs() < 0.88) {
    final targetY = ny >= 0 ? 1.0 : -1.0;
    final axis = n.cross(Vector3(0, targetY, 0));
    final len = axis.length;
    if (len > 1e-6) {
      axis.scale(1.0 / len);
      final rim = (1.0 - ny.abs()).clamp(0.0, 1.0);
      b.angularVelocity.add(axis * (16.0 * rim * flattenPull));
    }
  }
  // Ground friction can hold a rim stand; blend toward flat once the heading
  // is stable enough to keep in-plane yaw (do not nlerp on the equator).
  if (flattenPull > 0.4 && ny.abs() > 0.18) {
    final rest = restingOrientationFrom(b.orientation, faceUp: ny >= 0);
    b.orientation = _nlerpQuat(b.orientation, rest, 0.14 * flattenPull);
    b.angularVelocity.x *= 1.0 - 0.45 * flattenPull;
    b.angularVelocity.z *= 1.0 - 0.45 * flattenPull;
  }
  final w2 = b.angularVelocity.length2;
  if (ny.abs() > 0.72) {
    b.angularVelocity.x *= 0.55;
    b.angularVelocity.z *= 0.55;
  } else if (w2 < 0.55 && ny.abs() > 0.2) {
    b.angularVelocity.x *= 0.45;
    b.angularVelocity.z *= 0.45;
  }
}

void _snapRestingFace(_Body3 b) {
  final ny = b.orientation.rotated(Vector3(0, 1, 0)).y;
  if (ny.abs() < kFaceUpDot) return;
  b.orientation = restingOrientationFrom(
    b.orientation,
    faceUp: ny >= kFaceUpDot,
  );
}

Quaternion _nlerpQuat(Quaternion a, Quaternion b, double t) {
  var bx = b.x;
  var by = b.y;
  var bz = b.z;
  var bw = b.w;
  if (a.x * bx + a.y * by + a.z * bz + a.w * bw < 0) {
    bx = -bx;
    by = -by;
    bz = -bz;
    bw = -bw;
  }
  final q = Quaternion(
    a.x + (bx - a.x) * t,
    a.y + (by - a.y) * t,
    a.z + (bz - a.z) * t,
    a.w + (bw - a.w) * t,
  )..normalize();
  return q;
}

bool _posesClose(List a, List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final pa = a[i];
    final pb = b[i];
    if (pa is! List || pb is! List || pa.length < 8 || pb.length < 8) {
      return false;
    }
    for (var j = 1; j < 8; j++) {
      final va = pa[j] is num ? (pa[j] as num).toDouble() : 0.0;
      final vb = pb[j] is num ? (pb[j] as num).toDouble() : 0.0;
      if ((va - vb).abs() > 1e-3) return false;
    }
  }
  return true;
}
