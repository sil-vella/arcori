import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_resume_hooks.dart';
import 'app_ws_coordinator.dart';

/// Reconnects WebSockets and runs module resume hooks when the app is foregrounded.
class AppLifecycleObserver extends ConsumerStatefulWidget {
  const AppLifecycleObserver({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<AppLifecycleObserver> createState() =>
      _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    unawaited(_onResumed());
  }

  Future<void> _onResumed() async {
    await reconnectAppWebSockets(ref);
    await runAppResumeHooks(ref);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
