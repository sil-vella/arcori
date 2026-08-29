/// Forge2D side-view slam sim — authoritative pose timeline + resting faceUp.
library;

import 'dart:math';

import 'package:forge2d/forge2d.dart';

import '../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const double kSlamPhysicsDt = 1.0 / 60.0;
const int kSlamPhysicsSampleEvery = 2;
const int kSlamPhysicsMaxSteps = 120;
const double kSlamPhysicsPxPerMeter = 80.0;
const double kDiscRadius = 0.18;
const double kStackGap = 0.02;
const double kGroundFriction = 0.6;
const double kDiscFriction = 0.45;
const double kDiscRestitution = 0.35;
const double kDiscDensity = 1.0;
const double kLinearKickScale = 6.5;
const double kAngularKickScale = 4.5;
const double kSleepSpeed = 0.08;

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

bool isFaceUpAngle(double angleRad) {
  var a = angleRad % (2 * pi);
  if (a < 0) a += 2 * pi;
  return a > pi / 2 && a < 3 * pi / 2;
}

/// Run fixed-timestep Forge2D sim; discs collide and tumble to resting faces.
SlamPhysicsResult runSlamPhysics({
  required List<Map<String, dynamic>> pieces,
  required double dx,
  required double dy,
  required double speed,
  required double power,
  required int maxAffect,
  required Random rng,
}) {
  if (LOGGING_SWITCH) {
    customlog(
      'slamPhysics: start pieces=${pieces.length} power=${power.toStringAsFixed(3)} '
      'speed=${speed.toStringAsFixed(3)} dx=${dx.toStringAsFixed(3)} '
      'dy=${dy.toStringAsFixed(3)} maxAffect=$maxAffect',
    );
  }

  final sorted = List<Map<String, dynamic>>.from(pieces)
    ..sort((a, b) {
      final sa = a['stackIndex'] is int ? a['stackIndex'] as int : 0;
      final sb = b['stackIndex'] is int ? b['stackIndex'] as int : 0;
      return sa.compareTo(sb);
    });

  final world = World(Vector2(0, -10));

  final ground = world.createBody(
    BodyDef(type: BodyType.static, position: Vector2(0, -0.5)),
  );
  final groundShape = PolygonShape()..setAsBoxXY(8.0, 0.5);
  ground.createFixture(
    FixtureDef(groundShape, friction: kGroundFriction, restitution: 0.1),
  );

  // Soft side walls so discs stay in view.
  for (final x in [-3.5, 3.5]) {
    final wall = world.createBody(
      BodyDef(type: BodyType.static, position: Vector2(x, 2.0)),
    );
    final wallShape = PolygonShape()..setAsBoxXY(0.25, 4.0);
    wall.createFixture(FixtureDef(wallShape, friction: 0.2, restitution: 0.2));
  }

  final bodies = <Body>[];
  final ids = <String>[];
  final wasFaceUp = <bool>[];
  final prevAngles = <double>[];
  final tumbleAbs = <double>[];

  for (var i = 0; i < sorted.length; i++) {
    final p = sorted[i];
    final id = p['pieceId']?.toString() ?? 'p$i';
    final faceUp = p['faceUp'] == true;
    final startAngle = faceUp ? pi : 0.0;
    final y = kDiscRadius + i * (2 * kDiscRadius + kStackGap);
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: Vector2(0, y),
        angle: startAngle,
        userData: id,
        allowSleep: true,
        linearDamping: 0.15,
        angularDamping: 0.35,
      ),
    );
    body.createFixture(
      FixtureDef(
        CircleShape(radius: kDiscRadius),
        density: kDiscDensity,
        friction: kDiscFriction,
        restitution: kDiscRestitution,
      ),
    );
    bodies.add(body);
    ids.add(id);
    wasFaceUp.add(faceUp);
    prevAngles.add(startAngle);
    tumbleAbs.add(0.0);
  }

  // Kick topmost face-down discs (spread budget); punch through face-up tops.
  if (power >= 0.02 && bodies.isNotEmpty) {
    final len = sqrt(dx * dx + dy * dy);
    final ndx = len > 1e-6 ? dx / len : 0.0;
    // Screen dy>0 (down) → world −y (into stack / gravity).
    final ndy = len > 1e-6 ? -(dy.abs() / len) : -1.0;
    final kickLin = power * kLinearKickScale;
    final kickAng = power * kAngularKickScale;

    var affected = 0;
    for (var i = bodies.length - 1; i >= 0 && affected < maxAffect; i--) {
      if (wasFaceUp[i]) continue;
      final jitterX = (rng.nextDouble() - 0.5) * 0.15 * (1.1 - power);
      final vx = (ndx + jitterX) * kickLin;
      final vy = ndy * kickLin * (0.85 + 0.3 * speed);
      bodies[i].applyLinearImpulse(Vector2(vx, vy));
      final spinSign = rng.nextBool() ? 1.0 : -1.0;
      bodies[i].applyAngularImpulse(
        spinSign * kickAng * (0.7 + 0.6 * speed),
      );
      affected++;
    }

    // If only face-up tops exist, still nudge the top body so collisions can
    // transfer energy downward (punch-through).
    if (affected == 0) {
      final top = bodies.length - 1;
      bodies[top].applyLinearImpulse(
        Vector2(ndx * kickLin * 0.8, ndy * kickLin),
      );
      bodies[top].applyAngularImpulse(kickAng * 0.5);
      if (LOGGING_SWITCH) {
        customlog(
          'slamPhysics: punchThroughKick top=${ids[top]} '
          'kickLin=${kickLin.toStringAsFixed(2)}',
        );
      }
    } else if (LOGGING_SWITCH) {
      customlog(
        'slamPhysics: kicked faceDown=$affected kickLin=${kickLin.toStringAsFixed(2)} '
        'kickAng=${kickAng.toStringAsFixed(2)}',
      );
    }
  }

  List<List<dynamic>> samplePoses() {
    final poses = <List<dynamic>>[];
    for (var i = 0; i < bodies.length; i++) {
      final b = bodies[i];
      poses.add([
        ids[i],
        _round4(b.position.x),
        _round4(b.position.y),
        _round4(b.angle),
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
    world.stepDt(kSlamPhysicsDt);
    stepsRun = step;
    for (var i = 0; i < bodies.length; i++) {
      final a = bodies[i].angle;
      tumbleAbs[i] += (a - prevAngles[i]).abs();
      prevAngles[i] = a;
    }
    if (step % kSlamPhysicsSampleEvery == 0) {
      frames.add({'i': step, 'p': samplePoses()});
    }
    var allQuiet = true;
    for (final b in bodies) {
      if (b.linearVelocity.length2 > kSleepSpeed * kSleepSpeed ||
          b.angularVelocity.abs() > kSleepSpeed * 2) {
        allQuiet = false;
        break;
      }
    }
    if (allQuiet) {
      settledSteps++;
      if (settledSteps >= 8) break;
    } else {
      settledSteps = 0;
    }
  }

  // Ensure final sample is present.
  final lastI = frames.isEmpty ? 0 : (frames.last['i'] as int);
  if (lastI != kSlamPhysicsMaxSteps &&
      (frames.isEmpty ||
          !_posesClose(
            frames.last['p'] as List,
            samplePoses(),
          ))) {
    frames.add({'i': lastI + 1, 'p': samplePoses()});
  }

  final flipped = <String>[];
  final scoreDeltas = <String, int>{};
  final nextPieces = <Map<String, dynamic>>[];

  for (var i = 0; i < sorted.length; i++) {
    // Resting orientation OR enough tumble (¾ turn) counts as a flip.
    final tumbled = tumbleAbs[i] >= pi * 0.75;
    final faceUp = isFaceUpAngle(bodies[i].angle) || tumbled;
    final prev = Map<String, dynamic>.from(sorted[i]);
    final id = ids[i];
    if (!wasFaceUp[i] && faceUp) {
      flipped.add(id);
      final owner = prev['ownerUserId']?.toString() ?? '';
      if (owner.isNotEmpty) {
        scoreDeltas[owner] = (scoreDeltas[owner] ?? 0) + 1;
      }
    }
    // Already-up stays up even if angle wobbles into down half briefly.
    final finalFace = wasFaceUp[i] || faceUp;
    nextPieces.add({...prev, 'faceUp': finalFace});
  }

  if (LOGGING_SWITCH) {
    final tumbleSummary = [
      for (var i = 0; i < ids.length; i++)
        '${ids[i]}:${tumbleAbs[i].toStringAsFixed(2)}',
    ].join(',');
    customlog(
      'slamPhysics: done steps=$stepsRun frames=${frames.length} '
      'flipped=$flipped tumble=[$tumbleSummary]',
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
      'frames': frames,
    },
  );
}

double _round4(double v) => (v * 10000).roundToDouble() / 10000;

bool _posesClose(List a, List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final pa = a[i];
    final pb = b[i];
    if (pa is! List || pb is! List || pa.length < 4 || pb.length < 4) {
      return false;
    }
    for (var j = 1; j < 4; j++) {
      final va = pa[j] is num ? (pa[j] as num).toDouble() : 0.0;
      final vb = pb[j] is num ? (pb[j] as num).toDouble() : 0.0;
      if ((va - vb).abs() > 1e-3) return false;
    }
  }
  return true;
}
