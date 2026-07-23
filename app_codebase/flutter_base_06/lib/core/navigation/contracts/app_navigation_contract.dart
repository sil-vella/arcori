/// Single source of truth for imperative navigation in the Flutter app.
///
/// [GoRouter] owns location and back-stack depth; [Nav] is the only imperative
/// entry point screens and [AppShell] should call.
///
/// Rules:
/// 1. Screens and [AppShell] use [Nav] — not raw go_router APIs.
/// 2. Route registration files (`*_routes.dart`, `*_drawer.dart`) may import go_router and [AppPaths].
/// 3. [Nav.go] is for hard stack replacement (auth reset, splash) — not normal UI flow.
/// 4. [Nav.pushFromDrawer] pushes when the destination differs from the current location,
///    then always closes the drawer overlay.
library;

import 'package:flutter/material.dart';

abstract interface class AppNavigation {
  void push(String location, {Object? extra});
  void pop<T extends Object?>([T? result]);
  bool canPop();
  void pushFromDrawer(String location, {Object? extra, ScaffoldState? scaffold});
  void go(String location, {Object? extra});
}
