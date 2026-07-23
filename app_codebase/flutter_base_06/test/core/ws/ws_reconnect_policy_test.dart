import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/ws/ws_reconnect_policy.dart';

void main() {
  test('delayForAttempt grows with cap', () {
    const policy = WsReconnectPolicy(
      initialDelay: Duration(seconds: 1),
      maxDelay: Duration(seconds: 5),
      multiplier: 2,
    );
    expect(policy.delayForAttempt(0), const Duration(seconds: 1));
    expect(policy.delayForAttempt(1), const Duration(seconds: 2));
    expect(policy.delayForAttempt(2), const Duration(seconds: 4));
    expect(policy.delayForAttempt(3), const Duration(seconds: 5));
  });
}
