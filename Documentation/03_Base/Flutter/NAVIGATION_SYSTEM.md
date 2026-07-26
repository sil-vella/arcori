# arcori — Flutter navigation system

Technical guide for routing, shell chrome, drawer navigation, imperative `Nav`, and optional bottom action bar in **flutter_base_06**. For AppBar slots see [APPBAR_WIDGET_REGISTRATION.md](APPBAR_WIDGET_REGISTRATION.md). For bottom nav registration see [BOTTOM_NAV_REGISTRATION.md](BOTTOM_NAV_REGISTRATION.md). For modular state (Riverpod, auth, WS), see [STATE_SYSTEM.md](STATE_SYSTEM.md). For backend coordination, see [PYTHON_DART_BACKEND.md](../PYTHON_DART_BACKEND.md).

## Overview

Navigation is built on **go_router** with a single **ShellRoute** that wraps all feature routes in one shared `AppShell`. Feature modules never import `AppShell` or the concrete registries — they register routes and drawer placements (header, destinations, bottom icons) through **sink interfaces** at startup.

| Layer | Location | Role |
|-------|----------|------|
| Bootstrap | `lib/app_init.dart` | Reset registries, register modules, build router, run app |
| Route sink | `lib/core/navigation/app_route_registry.dart` | Collects `GoRoute` trees from modules |
| Drawer sink | `lib/core/navigation/app_drawer_registry.dart` | Collects header, destination rows, and bottom icon items |
| Bottom nav scope sink | `lib/core/bottom_nav/bottom_nav_registry.dart` | Collects module route prefixes for bottom bar |
| Shell | `lib/core/navigation/app_shell.dart` | One `Scaffold`: drawer, app bar, bottom bar, body |
| Imperative API | `lib/core/navigation/app_navigation.dart` | `Nav` — push, pop, go, drawer push |
| Path constants | `lib/core/navigation/app_paths.dart` | Central `/`, `/sample`, `/ws-demo`, … |
| Module wiring | `lib/modules/module_registry.dart` | Calls each feature's `register*Routes` / `register*Drawer` / `register*BottomNavScope` |

```text
main() → startApp()
           │
           ├─ resetAppRouteRegistry / resetAppDrawerRegistry / resetAppBarRegistry / resetBottomNavRegistry / …
           ├─ registerApplicationModules(appRouteSink, appDrawerSink, appBarSink, bottomNavScopeSink, …)
           ├─ appBarController.setModuleItems(…); bottomNavController.setModuleScopes(…)
           ├─ buildAppGoRouter()
           └─ runApp(MaterialApp.router(routerConfig: …))

GoRouter
  └── ShellRoute → AppShell(child: active route widget)
        └── GoRoute / GoRoute / …   (flat siblings from modules)
```

## Design principles

1. **Screens own body content only.** No per-screen `Scaffold`, drawer, or app bar. Chrome lives in `AppShell`.
2. **GoRouter is the single source of truth** for location and back-stack depth. There is no parallel manual nav stack.
3. **Imperative navigation goes through `Nav`.** Screens and shell must not call `context.push`, `context.pop`, or `GoRouter.of(context)` directly (avoids extension clashes and bypassing shell semantics).
4. **Registration files may use go_router.** `*_routes.dart` and `*_drawer.dart` import `go_router` and `AppPaths`; `*_screen.dart` imports `Nav` only.
5. **Registries are resettable** before each bootstrap so widget tests and hot restarts do not accumulate duplicate routes or drawer placements.

## Bootstrap sequence

`startApp()` in `app_init.dart` mirrors the Dart backend's `startApp` pattern:

```dart
void startApp() {
  WidgetsFlutterBinding.ensureInitialized();
  resetAppRouteRegistry();
  resetAppDrawerRegistry();
  resetAppBarRegistry();
  resetBottomNavRegistry();
  resetAppBarController();
  resetBottomNavController();
  registerApplicationModules(
    appRouteSink,
    appDrawerSink,
    appBarSink,
    bottomNavScopeSink,
    appStateSink,
  );
  appBarController.setModuleItems(appBarModuleItems);
  bottomNavController.setModuleScopes(bottomNavModuleScopes);
  runApp(const AppProviderScope(child: AppBootstrap()));
}
```

Widget tests replicate the same sequence, then use `rootAppForTesting(router)` instead of `runApp`.

## Route registration

### Sink contract

`AppRouteSink` (`lib/core/navigation/contracts/register_route_contract.dart`):

```dart
abstract interface class AppRouteSink {
  void addRoutes(List<RouteBase> routes);
}
```

The live implementation is `appRouteSink` in `app_route_registry.dart`.

### Building the router

`buildAppGoRouter()` wraps all module routes in one `ShellRoute`:

```dart
GoRouter buildAppGoRouter() {
  final routes = List<RouteBase>.of(_AppRouteRegistry._instance._routes);
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: routes,
      ),
    ],
  );
}
```

### Per-module pattern

Each feature provides `*_routes.dart`:

```dart
void registerSampleRoutes(AppRouteSink routes) {
  routes.addRoutes([
    GoRoute(
      path: AppPaths.sample,
      name: 'sample',
      builder: (context, state) => const SampleScreen(),
    ),
  ]);
}
```

Add a constant to `AppPaths`, register in `module_registry.dart`, and add a matching drawer row (see below).

## Drawer registration

### Sink contract

`AppDrawerSink` exposes three placements:

| Placement | Sink method | Capacity | Registry getter |
|-----------|-------------|----------|-----------------|
| Header | `setHeader(AppDrawerHeader)` | Exactly one (assert if called twice) | `appDrawerHeader` |
| Destinations | `addDestinations(...)` | Ordered list, unlimited | `appDrawerDestinations` |
| Bottom | `addBottomItems(...)` | Ordered list, unlimited | `appDrawerBottomItems` |

**Header** — module owns the widget via `WidgetBuilder`. At most one registration across the whole app.

```dart
drawer.setHeader(AppDrawerHeader(
  builder: (context) => /* module-owned header widget */,
));
```

**Destinations** — primary nav rows:

| Field | Purpose |
|-------|---------|
| `path` | Same string as the feature's `GoRoute.path` |
| `label` | Drawer row text |
| `icon` / `selectedIcon` | Material icons for unselected / selected state |

Example (`home_drawer.dart`):

```dart
void registerHomeDrawer(AppDrawerSink drawer) {
  drawer.addDestinations(const [
    AppDrawerDestination(
      path: AppPaths.home,
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
  ]);
}
```

**Bottom** — horizontal icon row at the drawer foot. Each item is an icon that navigates to a screen path. Layout (when wired in `AppShell`): fill left → right; when a row is full, wrap one level upward. No item limit.

| Field | Purpose |
|-------|---------|
| `path` | Same string as the feature's `GoRoute.path` |
| `icon` | Material icon for the control |
| `tooltip` | Optional accessibility / long-press hint |

```dart
drawer.addBottomItems(const [
  AppDrawerBottomItem(path: AppPaths.settings, icon: Icons.settings_outlined),
]);
```

Registry getters (`appDrawerHeader`, `appDrawerDestinations`, `appDrawerBottomItems`) are the shell’s read API. `AppShell` currently renders destination rows in a Material 3 `NavigationDrawer`; header and bottom icon-row UI wiring is not hooked up yet.

### Drawer selection highlight

The selected row is derived from **`Nav.matchedLocation(context)`**, not from a manual stack. That reads `GoRouter.of(context).routerDelegate.state.matchedLocation`, which includes routes pushed imperatively via `Nav.push`.

Path prefix matching supports nested routes later (e.g. `/sample/detail` highlights the Sample row).

## Imperative API — `Nav`

`Nav` (`lib/core/navigation/app_navigation.dart`) is the only entry point for runtime navigation from screens and shell.

| Method | Behavior |
|--------|----------|
| `Nav.push(context, location)` | Pushes onto go_router stack |
| `Nav.pop(context)` | Pops when `router.canPop()`; no-op at root |
| `Nav.canPop(context)` | Delegates to `GoRouter.canPop()` |
| `Nav.go(context, location)` | Replaces entire stack — auth reset, splash exit |
| `Nav.pushFromDrawer(context, location, scaffold: …)` | Closes drawer; pushes only if destination ≠ current location |
| `Nav.matchedLocation(context)` | Active location including imperative pushes |

### Rules (also documented in `app_navigation_contract.dart`)

1. Screens and `AppShell` use **`Nav`** — not raw go_router context extensions.
2. `*_routes.dart` / `*_drawer.dart` may import go_router and `AppPaths`.
3. **`Nav.go`** is for hard stack replacement, not normal in-app flow.
4. **`Nav.pushFromDrawer`** always closes the drawer; re-selecting the current row only dismisses the drawer (no duplicate push).

### Example — in-screen navigation

```dart
FilledButton.tonal(
  onPressed: () => Nav.push(context, AppPaths.sample),
  child: const Text('Open sample module'),
),
```

## AppShell behavior

`AppShell` owns:

- `PopScope` — intercepts system back when `Nav.canPop` is true
- `ShellAppBar` + `ShellNavControls` — back button, registrable toolbar slots, hamburger menu
- `NavigationDrawer` — module-registered destinations (header + bottom icon-row placements registered via `AppDrawerSink`; shell UI for those slots pending)
- `ShellBottomBar` — optional per-screen module action row (hidden when no items); unrelated to drawer bottom icons
- `body` — active route widget from go_router

See [BOTTOM_NAV_REGISTRATION.md](BOTTOM_NAV_REGISTRATION.md) for bottom bar registration. See [APPBAR_WIDGET_REGISTRATION.md](APPBAR_WIDGET_REGISTRATION.md) for toolbar slots.

### Back button and system back

```dart
PopScope(
  canPop: !Nav.canPop(context),
  onPopInvokedWithResult: (didPop, result) {
    if (!didPop && Nav.canPop(context)) {
      Nav.pop(context);
    }
  },
  …
)
```

When the stack has depth, the shell shows a back button and routes OS back through `Nav.pop`.

### Chrome sync after route changes

go_router's `ShellRoute` can swap the route **`child`** without rebuilding `AppShell`'s `State`. To keep back/menu/drawer highlight in sync, `AppShell` implements:

```dart
@override
void didUpdateWidget(covariant AppShell oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.child != widget.child) {
    _scheduleRebuild(); // post-frame setState when needed
  }
}
```

Do not remove this hook — it fixes stale chrome after the first imperative push.

## Auth redirects

`GoRouter.redirect` uses `redirectForAuth` (`lib/core/navigation/auth_redirect.dart`) with `AppPaths.requiresAuth`:

| Route | Auth required |
|-------|----------------|
| `/ws-demo` | Yes — redirects to `/login?from=…` |
| `/example-module`, `/`, `/sample` | No — bottom nav and screen body available without login |

Bottom nav registration is **not** gated on login. Protected routes redirect before the feature screen mounts; use `visibleWhen` on individual bottom actions when an action needs a session.

## Navigation UX model

Current template behavior:

| Action | Effect |
|--------|--------|
| Tap in-screen link | `Nav.push` — adds to stack |
| Tap drawer row (different section) | `Nav.pushFromDrawer` — adds to stack |
| Tap drawer row (same section) | Drawer closes only |
| Back / system back | `Nav.pop` — unwinds stack |
| `Nav.go` | Clears stack to target (reserved for auth/splash) |

This produces a **cross-section back stack** (e.g. Home → Sample → WS Demo, back unwinds through history). That is intentional in the template but differs from the common "drawer = section switch (`go`)" pattern. When the app grows, consider migrating to `StatefulShellRoute` (Option A) if drawer rows should be parallel sections rather than sequential history.

## Adding a new module

1. Create `lib/modules/<name>/`:
   - `<name>_routes.dart` — `register<Name>Routes(AppRouteSink, NotificationScreenSink)` (register navigable slug beside [GoRoute])
   - `<name>_drawer.dart` — `register<Name>Drawer(AppDrawerSink)` — usually `addDestinations`; optionally `addBottomItems`; at most one module in the app may `setHeader`
   - `<name>_screen.dart` — body widget; use `ModuleScreenRegistrar` or `AppBarRegistrar` (see AppBar / bottom nav docs)
   - `<name>_bottom_nav.dart` — optional `register<Name>BottomNavScope` + item factory (shell bottom bar, not drawer bottom icons)
2. Add path to `AppPaths`.
3. Wire calls in `module_registry.dart` (routes, drawer, optional bottom nav scope).
4. Add widget tests if navigation or chrome behavior is non-trivial.

## Testing

Navigation tests live in `test/core/navigation/app_navigation_test.dart`. Pattern:

```dart
resetAppRouteRegistry();
resetAppDrawerRegistry();
resetAppBarRegistry();
resetBottomNavRegistry();
resetNotificationScreenRegistry();
resetAppBarController();
resetBottomNavController();
registerApplicationModules(
  appRouteSink,
  appDrawerSink,
  appBarSink,
  bottomNavScopeSink,
  appStateSink,
  notificationScreenSink,
);
appBarController.setModuleItems(appBarModuleItems);
bottomNavController.setModuleScopes(bottomNavModuleScopes);
await tester.pumpWidget(rootAppForTesting());
await tester.pumpAndSettle();
```

Coverage includes: root chrome (menu, no back), push/pop, drawer stack unwind, app bar title sync, drawer re-select.

## File reference

| File | Purpose |
|------|---------|
| `lib/core/navigation/app_navigation.dart` | `Nav` static API |
| `lib/core/navigation/app_shell.dart` | Shared scaffold chrome |
| `lib/core/navigation/app_route_registry.dart` | Route sink + `buildAppGoRouter` |
| `lib/core/navigation/app_drawer_registry.dart` | Drawer sink |
| `lib/core/navigation/app_paths.dart` | Path constants |
| `lib/core/navigation/contracts/register_route_contract.dart` | `AppRouteSink` |
| `lib/core/navigation/contracts/register_drawer_contract.dart` | `AppDrawerSink`, `AppDrawerHeader`, `AppDrawerDestination`, `AppDrawerBottomItem` |
| `lib/core/navigation/contracts/app_navigation_contract.dart` | `AppNavigation` interface (documentation / future DI) |
| `lib/core/bottom_nav/bottom_nav_registry.dart` | Bottom nav scope sink |
| `lib/core/bottom_nav/shell_bottom_bar.dart` | Shell bottom action bar |
| `lib/core/screen/module_screen_registrar.dart` | AppBar + bottom nav screen wrapper |
| `lib/modules/module_registry.dart` | Central module wiring |

## Future evolution

| Need | Direction |
|------|-----------|
| Nested module routes (`/sample/:id`) | Keep flat routes or nest under each module's `GoRoute` |
| Drawer as section tabs (no cross-section back) | `StatefulShellRoute.indexedStack` + `goBranch` |
| Auth guards | `GoRouter.redirect` + `Nav.go` after login/logout |
| Deep links / web URL sync | See [DEEP_LINKS.md](DEEP_LINKS.md) for App/Universal Links (`/arcori-verify-email`); keep browser-only paths out of AASA |
| Injectable navigation for tests | Implement `AppNavigation` on a concrete class; inject via provider |
