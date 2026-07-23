import 'dart:io';

const _truthy = {'1', 'true', 'yes'};

bool isDutchDevLogTruthy(String? raw) =>
    _truthy.contains((raw ?? '').trim().toLowerCase());

bool get _dutchDevLogEnabled => isDutchDevLogTruthy(Platform.environment['DUTCH_DEV_LOG']);

/// Developer-facing log — gated by DUTCH_DEV_LOG, emits [dev] prefix on stderr.
void customlog(String message) {
  if (!_dutchDevLogEnabled) return;
  stderr.writeln('[dev] $message');
}
