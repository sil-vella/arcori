# arcori — Bottom nav and shell action bar

Technical guide for the **screen-scoped bottom action bar** in **flutter_base_06**: module route scopes, per-screen item registration, and `ShellBottomBar` rendering. For routing, drawer, and `Nav`, see [NAVIGATION_SYSTEM.md](NAVIGATION_SYSTEM.md). For AppBar slots, see [APPBAR_WIDGET_REGISTRATION.md](APPBAR_WIDGET_REGISTRATION.md).

## Overview

The bottom bar is an **optional shell action row** — not primary tab navigation. It is **hidden by default** and appears only when a screen registers items for its module. Works on **web, Android, and iOS** (same Material shell; “shell” means app frame UI, not the Chrome browser).

| Layer | Location | Role |
|-------|----------|------|
| Contracts | `lib/core/bottom_nav/contracts/register_bottom_nav_contract.dart` | `BottomNavItem`, `BottomNavScopeSink` |
| Scope registry | `lib/core/bottom_nav/bottom_nav_registry.dart` | Module `pathPrefixes` at startup |
| Controller | `lib/core/bottom_nav/bottom_nav_controller.dart` | Merges scopes + screen stack |
| Scope | `lib/core/bottom_nav/bottom_nav_scope.dart` | `InheritedWidget` for registrars |
| Screen registrar | `lib/core/bottom_nav/bottom_nav_registrar.dart` | Pushes/pops items via widget lifecycle |
| Shell widget | `lib/core/bottom_nav/shell_bottom_bar.dart` | Renders icon actions + overflow |
| Screen helper | `lib/core/screen/module_screen_registrar.dart` | Optional AppBar + bottom nav wrapper |
| Shell wiring | `lib/core/navigation/app_shell.dart` | `BottomNavScope`, `ShellBottomBar` |

```text
startApp()
  └─ bottomNavController.setModuleScopes(bottomNavModuleScopes)   ← from BottomNavScopeSink

AppShell
  └─ BottomNavScope(controller: bottomNavController)
       ├─ ShellBottomBar  ← items from BottomNavController.itemsFor(context)
       └─ body
            └─ Screen
                 └─ BottomNavRegistrar(moduleId, items)   ← or ModuleScreenRegistrar
                      └─ AppBarRegistrar / screen content
```

## Design principles

1. **Hidden by default** — no registrar on a screen means no bottom bar.
2. **Module isolation** — items render only when `moduleId` is registered and `Nav.matchedLocation` matches a scope `pathPrefix`.
3. **Not auth-gated at the shell** — route protection is separate (`AppPaths.requiresAuth`). Individual buttons may use `visibleWhen` (e.g. WS connect when signed in).
4. **Action bar, not tab bar** — use `BottomNavAction` / `BottomNavNavigate`; do not use M3 `NavigationBar` for this layer.
5. **Cross-module navigation** — use `BottomNavAction` + `Nav.push` / `Nav.go`; `BottomNavNavigate` only allows paths inside the module’s registered prefixes.

## Bootstrap

`startApp()` resets and loads scopes after module registration:

```dart
resetBottomNavRegistry();
resetBottomNavController();
registerApplicationModules(
  appRouteSink,
  appDrawerSink,
  appBarSink,
  bottomNavScopeSink,
  appStateSink,
);
bottomNavController.setModuleScopes(bottomNavModuleScopes);
```

Widget tests must include the same resets (see `test/helpers/app_test_boot.dart`).

## Module scope registration

At startup, each module that uses the bottom bar declares allowed route prefixes:

```dart
void registerExampleModuleBottomNavScope(BottomNavScopeSink sink) {
  sink.registerScope(
    moduleId: 'example_module',
    pathPrefixes: [AppPaths.exampleModule],
  );
}
```

Wire in `module_registry.dart`:

```dart
registerExampleModuleBottomNavScope(bottomNav);
```

Nested routes under a prefix (e.g. `/example-module/settings`) are covered automatically.

## Screen registration

### Option A — `ModuleScreenRegistrar` (recommended)

Combines AppBar + bottom nav registration:

```dart
return ModuleScreenRegistrar(
  appBarItems: const [AppBarTitle(text: 'Example module', icon: Icons.extension_outlined)],
  bottomNavModuleId: exampleModuleBottomNavModuleId,
  bottomNavItems: exampleModuleBottomNavItems(context),
  child: /* body only */,
);
```

### Option B — `BottomNavRegistrar` only

```dart
return BottomNavRegistrar(
  moduleId: wsDemoBottomNavModuleId,
  items: wsDemoBottomNavItems(context, ref),
  child: AppBarRegistrar(
    items: const [AppBarTitle(text: 'WebSocket Demo')],
    child: /* body */,
  ),
);
```

## Item types

| Type | Use |
|------|-----|
| `BottomNavAction` | Custom `onTap` — connect WS, toggle, **`Nav.push` to another module** |
| `BottomNavNavigate` | In-module navigation via `Nav.push`; path validated against module scope |

Example — cross-module home shortcut (`example_module_bottom_nav.dart`):

```dart
BottomNavAction(
  icon: Icons.home_outlined,
  tooltip: 'Go to Home',
  onTap: () => Nav.push(context, AppPaths.home),
),
```

Example — conditional visibility (`ws_demo_bottom_nav.dart`):

```dart
BottomNavAction(
  icon: Icons.link,
  tooltip: 'Connect both WS',
  onTap: () async { /* … */ },
  visibleWhen: (_) => auth.isAuthenticated,
),
```

## Isolation and visibility

`BottomNavController.itemsFor(context)` returns items only when:

1. A `BottomNavRegistrar` is mounted (top of screen stack)
2. `moduleId` has a registered scope
3. Current location matches a `pathPrefix` (exact or `prefix/…`)
4. Each item’s `visibleWhen` passes

During route transitions (pop/push), location may change before the registrar disposes — the controller returns `[]` briefly (bar hidden). Unknown `moduleId` asserts in debug only.

**Do not tie bar visibility to `Nav.canPop`** — pushed module screens should keep their actions.

## Auth vs bottom nav

| Concern | Behavior |
|---------|----------|
| Example module screen | Public — no login redirect |
| WS Demo screen | Protected — `AppPaths.requiresAuth` redirects to `/login` |
| Bottom bar on login | Never shown — `LoginScreen` has no registrar |
| Per-button auth | Optional `visibleWhen` on items |

## Shell layout

`AppShell` owns:

- `ShellAppBar` + `ShellNavControls` (back, menu)
- `NavigationDrawer` — destination rows today; header + bottom icon-row placements are registered on `AppDrawerSink` (see [NAVIGATION_SYSTEM.md](NAVIGATION_SYSTEM.md))
- `ShellBottomBar` (when items exist) — this doc; not the drawer’s bottom icon row
- `body` — active route

Screens must not add a second `Scaffold` for shell chrome (login is a known exception with its own local app bar).

## Adding a new module

1. Create `modules/<name>/<name>_bottom_nav.dart` — `registerXBottomNavScope` + item factory
2. Register scope in `module_registry.dart`
3. On screens that need actions: `ModuleScreenRegistrar` or `BottomNavRegistrar`
4. Add widget tests in `test/core/bottom_nav/` if behavior is non-trivial

## Testing

Tests: `test/core/bottom_nav/bottom_nav_test.dart`

Coverage includes: hidden on home, visible on WS demo, not visible on other modules, example module home shortcut, scope path matching.

## File reference

| File | Purpose |
|------|---------|
| `lib/core/bottom_nav/contracts/register_bottom_nav_contract.dart` | Types, `BottomNavScopeSink` |
| `lib/core/bottom_nav/bottom_nav_registry.dart` | Scope sink + `bottomNavModuleScopes` |
| `lib/core/bottom_nav/bottom_nav_controller.dart` | Merge logic, singleton |
| `lib/core/bottom_nav/bottom_nav_scope.dart` | Inherited controller |
| `lib/core/bottom_nav/bottom_nav_registrar.dart` | Screen-scoped widget |
| `lib/core/bottom_nav/shell_bottom_bar.dart` | Shell bottom action row |
| `lib/core/screen/module_screen_registrar.dart` | AppBar + bottom nav helper |
| `lib/core/navigation/app_shell.dart` | Wires `ShellBottomBar` |
| `lib/modules/ws_demo/ws_demo_bottom_nav.dart` | WS demo actions |
| `lib/modules/example_module/example_module_bottom_nav.dart` | Example “Go to Home” action |

## Common mistakes

| Mistake | Correct approach |
|---------|------------------|
| Expecting bar on login screen | Register only on feature screens |
| `BottomNavNavigate` to another module’s path | Use `BottomNavAction` + `Nav.push` |
| Putting bottom items in `AppBarSink` | Screen-scoped registrar only (v1) |
| Auth-blocking example module route | Only WS routes need `requiresAuth` for shell demo |
| Per-screen `Scaffold` + bottom bar | Shell owns `ShellBottomBar` |

## Future evolution

| Need | Direction |
|------|-----------|
| Permanent module actions | `BottomNavSink.addItems()` (not in v1) |
| Primary tab navigation | `StatefulShellRoute` — separate from this action bar |
| More than 5 actions | `ShellBottomBar` overflow menu (implemented) |
