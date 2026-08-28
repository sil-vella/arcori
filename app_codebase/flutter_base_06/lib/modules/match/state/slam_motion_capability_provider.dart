import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../input/slam_motion_capability.dart';

/// Device-level shake availability — probed once per app process at bootstrap.
///
/// Not persisted: hardware does not change between sessions; probe is ~600ms
/// and runs in parallel with auth bootstrap. Do not re-probe per match.
class SlamShakeCapability extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    ref.keepAlive();
    return probeSlamShakeAvailable();
  }
}

final slamShakeAvailableProvider =
    AsyncNotifierProvider<SlamShakeCapability, bool>(
  SlamShakeCapability.new,
);
