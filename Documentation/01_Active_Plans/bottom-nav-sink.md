# Bottom Nav Sink — Active Plan

## Status: Complete

Screen-scoped bottom action bar for module-specific shortcuts. Hidden by default; visible only when a screen registers items and the route matches the module scope.

**Full reference:** [BOTTOM_NAV_REGISTRATION.md](../03_Base/Flutter/BOTTOM_NAV_REGISTRATION.md)

## Architecture

- **Core:** `lib/core/bottom_nav/` — contracts, scope registry, controller, registrar, `ShellBottomBar`
- **Screen helper:** `lib/core/screen/module_screen_registrar.dart` — optional AppBar + bottom nav wrapper
- **Shell:** `AppShell` renders `ShellBottomBar` via `BottomNavScope`
- **Bootstrap:** `app_init.dart` resets registry/controller and loads module scopes
- **Pilot modules:** `ws_demo` (Connect / Ping), `example_module` (Go to Home)

## Naming (shell UI)

“Shell” = app frame UI on web, Android, and iOS — not the Chrome browser.

| Widget | File |
|--------|------|
| `ShellAppBar` | `lib/core/app_bar/shell_app_bar.dart` |
| `ShellNavControls` | `register_app_bar_contract.dart` |
| `ShellBottomBar` | `lib/core/bottom_nav/shell_bottom_bar.dart` |
| `ModuleScreenRegistrar` | `lib/core/screen/module_screen_registrar.dart` |

## Registration pattern

1. **Module startup** — `registerXBottomNavScope(bottomNavScopeSink)` declares `moduleId` + `pathPrefixes`
2. **Screen** — `ModuleScreenRegistrar` or `BottomNavRegistrar(moduleId: ..., items: ...)`
3. **Items** — `BottomNavAction` (custom / cross-module `Nav.push`) or `BottomNavNavigate` (in-module only)

## Isolation and auth

- No registrar → bar hidden
- Registrar `moduleId` must match a registered scope
- Current route must match a `pathPrefix`
- Example module is **public** (no login redirect); WS Demo requires auth for the **route**, not the bottom bar system
- Per-button auth via `visibleWhen` only (e.g. WS connect)

## Completed phases

- [x] Contracts (`BottomNavItem`, `BottomNavAction`, `BottomNavNavigate`, `BottomNavScopeSink`)
- [x] Controller, registry, scope, registrar
- [x] `ShellBottomBar` with overflow for 5+ items
- [x] Shell + bootstrap wiring
- [x] `ModuleScreenRegistrar` helper
- [x] WS demo + example module pilots
- [x] Shell rename (`Chrome*` → `Shell*`)
- [x] Widget tests (`test/core/bottom_nav/bottom_nav_test.dart`)
- [x] Base docs (`BOTTOM_NAV_REGISTRATION.md`, updates to `NAVIGATION_SYSTEM.md`, `EXAMPLE_MODULE.md`)

## Out of scope (v1)

- Permanent/conditional module-level bottom items (`BottomNavSink.addItems`)
- `StatefulShellRoute` per-tab stacks
- Moving all WS body controls into the bottom bar

## Adding a new module

1. Create `modules/<module>/<module>_bottom_nav.dart` with `registerXBottomNavScope` and item factory
2. Call scope registration from `module_registry.dart`
3. Use `ModuleScreenRegistrar` on screens that need bottom actions
