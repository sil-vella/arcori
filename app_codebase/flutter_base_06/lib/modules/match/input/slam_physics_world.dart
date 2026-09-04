/// Pure-Dart 3D thin-cylinder slam sim — authoritative xyzq pose timeline.
library;

import 'dart:math';

import 'package:vector_math/vector_math.dart';

import '../../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const double kSlamPhysicsDt = 1.0 / 60.0;
const int kSlamPhysicsSampleEvery = 2;
/// Shorter budget — soft settle + snap blend should finish well under this.
const int kSlamPhysicsMaxSteps = 70;
/// After this step, damp hard so quiet-exit can fire.
const int kSlamPhysicsSoftSettleAt = 36;
/// Multi-frame orientation/height blend to flat (avoids abrupt last-frame snap).
const int kSlamPhysicsSnapBlendSteps = 16;
/// ~50mm diameter draws near the 72px disc widget.
const double kSlamPhysicsPxPerMeter = 1440.0;
const String kSlamPhysicsSpace = 'xyzq';

/// Real-ish Arcori puck: Ø50mm × 3mm thick.
const double kDiscRadius = 0.025;
const double kDiscHalfHeight = 0.0015;
const double kStackGap = 0.0002;
const double kDiscFriction = 0.62;
/// Near-inelastic — less rebound chatter / bounce loops.
const double kDiscRestitution = 0.015;
/// Heavier puck — collision response softer; kicks still set ω/v directly.
const double kDiscMass = 2.8;
/// Stronger lateral scatter; lighter tumble so discs don't linger on edge.
const double kLinearKickScale = 0.98;
const double kAngularKickScale = 0.38;
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
const double kAngularDamping = 0.96;
/// Softens low power more than high.
const double kPowerKickExponent = 1.25;
/// Below this, kicks taper further so ~0.08 rarely flips.
const double kWeakKickFloor = 0.14;
const double kMaxLinSpeed = 0.95;
const double kMaxAngSpeed = 2.8;
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
      'dy=${dy.toStringAsFixed(3)} maxAffect=$maxAffect space=$kSlamPhysicsSpace',
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
    final kickLin = powerCurve * kLinearKickScale;
    final kickAng = powerCurve * kAngularKickScale;
    // Kick from the top; low/mid power hits fewer discs — collisions spread energy.
    final affectBudget = power < 0.35
        ? 1
        : (power < 0.65 ? min(2, maxAffect) : maxAffect);

    var affected = 0;
    for (var i = bodies.length - 1; i >= 0 && affected < affectBudget; i--) {
      final fromTop = bodies.length - 1 - i;
      if (wasFaceUp[i]) {
        // Shove face-up discs aside so face-down below can tip (punch-through).
        if (power >= 0.4) {
          final clear = kickLin * (0.95 + 0.5 * speed) * spreadMul;
          final fan = (rng.nextDouble() - 0.5) * 2.8 * spreadMul;
          bodies[i].linearVelocity.add(
            Vector3(
              (vx + latX * fan) * clear * 2.15,
              0.22 * clear,
              (vz + latZ * fan) * clear * 2.05,
            ),
          );
        }
        continue;
      }
      final jitterX = (rng.nextDouble() - 0.5) * 0.35 * (1.1 - power);
      final jitterZ = (rng.nextDouble() - 0.5) * 0.35 * (1.1 - power);
      // Wide alternating fan — separate discs so collisions die sooner.
      final fan =
          ((affected % 2 == 0) ? 1.0 : -1.0) *
          (1.05 + fromTop * 0.55 + rng.nextDouble() * 0.95) *
          spreadMul *
          (0.9 + power);
      final scale = kickLin * (1.15 + 0.45 * speed) * (1.0 + fromTop * 0.2);
      bodies[i].linearVelocity.add(
        Vector3(
          (vx + latX * fan + jitterX) * scale,
          vy * scale * 0.75,
          (vz + latZ * fan + jitterZ) * scale,
        ),
      );
      // Short tip about X — cross equator fast; damping kills lingering edge spin.
      final spinSign = rng.nextBool() ? 1.0 : -1.0;
      var ang = kickAng * (0.7 + 0.4 * speed);
      final hasUpAbove = wasFaceUp.sublist(i + 1).any((u) => u);
      if (hasUpAbove) {
        ang *= 1.2;
        punchedThrough.add(i);
      }
      bodies[i].angularVelocity.add(
        Vector3(spinSign * ang * 1.1, 0, -ndx * ang * 0.06),
      );
      if (hasUpAbove) {
        bodies[i].linearVelocity.add(
          Vector3(vx * kickLin * 0.45, -kickLin * 0.12, vz * kickLin * 0.4),
        );
      }
      affected++;
    }

    if (affected == 0) {
      final top = bodies.length - 1;
      final scale = kickLin * 1.15 * spreadMul;
      final fan = (rng.nextDouble() - 0.5) * 2.2 * spreadMul;
      bodies[top].linearVelocity.add(
        Vector3(
          (vx + latX * fan) * scale,
          vy * scale * 0.75,
          (vz + latZ * fan) * scale,
        ),
      );
      bodies[top].angularVelocity.add(Vector3(kickAng * 0.22, 0, kickAng * 0.08));
      if (LOGGING_SWITCH) {
        customlog(
          'slamPhysics: punchThroughKick top=${ids[top]} '
          'kickLin=${kickLin.toStringAsFixed(2)}',
        );
      }
    } else if (LOGGING_SWITCH) {
      customlog(
        'slamPhysics: kicked faceDown=$affected kickLin=${kickLin.toStringAsFixed(2)} '
        'kickAng=${kickAng.toStringAsFixed(2)} spreadMul=${spreadMul.toStringAsFixed(2)}',
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
  for (var step = 1; step <= kSlamPhysicsMaxSteps; step++) {
    if (step >= kSlamPhysicsSoftSettleAt) {
      for (final b in bodies) {
        b.linearVelocity.scale(0.78);
        b.angularVelocity.scale(0.68);
        if (b.position.y > kDiscHalfHeight) {
          b.position.y += (kDiscHalfHeight - b.position.y) * 0.2;
        }
      }
    }
    _stepWorld(bodies);
    stepsRun = step;
    if (step % kSlamPhysicsSampleEvery == 0) {
      frames.add({'i': step, 'p': samplePoses()});
    }
    var allQuiet = true;
    for (final b in bodies) {
      if (b.linearVelocity.length2 > kSleepLin * kSleepLin ||
          b.angularVelocity.length2 > kSleepAng * kSleepAng) {
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
    if (wasFaceUp[i]) {
      faceUp = true;
    }
    targetQ.add(faceOrientation(faceUp: faceUp));
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

void _stepWorld(List<_Body3> bodies) {
  const dt = kSlamPhysicsDt;
  final gravity = Vector3(0, -10, 0);

  for (final b in bodies) {
    b.linearVelocity.add(gravity * dt);
    b.linearVelocity.scale(1.0 - kLinearDamping * dt);
    b.angularVelocity.scale(1.0 - kAngularDamping * dt);
    _clampVel(b);
    b.position.add(b.linearVelocity * dt);
    _integrateOrientation(b.orientation, b.angularVelocity, dt);
    _assistFaceSettle(b);
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

/// Nudge off the rim without sustaining wake; kill spin once past equator.
void _assistFaceSettle(_Body3 b) {
  final ny = b.orientation.rotated(Vector3(0, 1, 0)).y;
  if (ny.abs() < 0.28) {
    b.angularVelocity.scale(0.62);
    if (b.angularVelocity.length2 < 0.65) {
      b.angularVelocity.x += (ny >= 0 ? 1.0 : -1.0) * 2.0;
    }
  } else if (ny.abs() > 0.5) {
    b.angularVelocity.scale(0.4);
  }
}

void _snapRestingFace(_Body3 b) {
  final ny = b.orientation.rotated(Vector3(0, 1, 0)).y;
  if (ny >= kFaceUpDot) {
    b.orientation = Quaternion.identity();
  } else if (ny <= -kFaceUpDot) {
    b.orientation = faceOrientation(faceUp: false);
  }
  // |ny| < kFaceUpDot: leave on edge — no flip credit.
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
