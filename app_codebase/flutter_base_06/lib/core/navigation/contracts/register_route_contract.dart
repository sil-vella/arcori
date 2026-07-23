/// Let feature modules attach UI routes without knowing how the global router is built.
///
/// The live implementation is [appRouteSink] in `app_route_registry.dart`. During startup,
/// [registerApplicationModules] (from `modules/module_registry.dart`) runs so each feature adds
/// [RouteBase] entries here; then [buildAppGoRouter] produces the [GoRouter] for the running app.
library;

import 'package:go_router/go_router.dart';

/// Collects route branches from feature modules. Prefer adding whole subtrees with
/// [addRoutes] rather than importing the concrete registry from feature code.
abstract interface class AppRouteSink {
  void addRoutes(List<RouteBase> routes);
}
