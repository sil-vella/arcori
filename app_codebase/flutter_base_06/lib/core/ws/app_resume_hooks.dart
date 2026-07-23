import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Invoked when the app returns to foreground — modules refresh inbox, etc.
typedef AppResumeHook = Future<void> Function(WidgetRef ref);

final List<AppResumeHook> _appResumeHooks = [];

void registerAppResumeHook(AppResumeHook hook) {
  _appResumeHooks.add(hook);
}

void resetAppResumeHooks() {
  _appResumeHooks.clear();
}

Future<void> runAppResumeHooks(WidgetRef ref) async {
  for (final hook in _appResumeHooks) {
    await hook(ref);
  }
}
