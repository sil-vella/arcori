import 'package:flutter/foundation.dart';

const _truthy = {'1', 'true', 'yes'};

bool isDutchDevLogTruthy(String? raw) =>
    _truthy.contains((raw ?? '').trim().toLowerCase());

bool _dutchDevLogEnabled() {
  const fromDefine = String.fromEnvironment('DUTCH_DEV_LOG');
  if (fromDefine.isNotEmpty) {
    return isDutchDevLogTruthy(fromDefine);
  }
  return kDebugMode;
}

/// Developer-facing log — gated by DUTCH_DEV_LOG, emits [dev] prefix via debugPrint.
void customlog(String message) {
  if (!_dutchDevLogEnabled()) return;
  debugPrint('[dev] $message');
}
