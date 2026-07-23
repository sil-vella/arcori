import 'dart:io';

import 'package:flutter/foundation.dart';

const _truthy = {'1', 'true', 'yes'};

bool isDutchDevLogTruthy(String? raw) =>
    _truthy.contains((raw ?? '').trim().toLowerCase());

bool _dutchDevLogEnabled() {
  const fromDefine = String.fromEnvironment('DUTCH_DEV_LOG');
  if (fromDefine.isNotEmpty) {
    return isDutchDevLogTruthy(fromDefine);
  }
  final fromEnv = Platform.environment['DUTCH_DEV_LOG'] ?? '';
  if (fromEnv.isNotEmpty) {
    return isDutchDevLogTruthy(fromEnv);
  }
  return false;
}

/// Developer-facing log — gated by DUTCH_DEV_LOG, emits [dev] prefix via debugPrint.
void customlog(String message) {
  if (!_dutchDevLogEnabled()) return;
  debugPrint('[dev] $message');
}
