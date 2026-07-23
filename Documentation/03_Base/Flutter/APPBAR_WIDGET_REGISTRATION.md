# arcori — AppBar and widget registration system

Technical guide for the layered AppBar in **flutter_base_06**: typed item registration, slot layout, screen vs module lifetime, and responsive overflow. For routing, drawer, and `Nav`, see [NAVIGATION_SYSTEM.md](NAVIGATION_SYSTEM.md).

## Overview

The app uses a **single shared AppBar** owned by `AppShell`. Screens do not create their own `AppBar` or `Scaffold`. Instead, features register toolbar content through a typed **`AppBarItem`** hierarchy and an **`AppBarRegistrar`** widget that scopes items to the active screen's lifetime.

| Layer | Location | Role |
|-------|----------|------|
| Contracts | `lib/core/app_bar/contracts/register_app_bar_contract.dart` | `AppBarItem`, slots, lifetimes, `AppBarSink` |
| Module registry | `lib/core/app_bar/app_bar_registry.dart` | Collects permanent/conditional items at startup |
| Controller | `lib/core/app_bar/app_bar_controller.dart` | Merges module + screen scopes; notifies listeners |
| Scope | `lib/core/app_bar/app_bar_scope.dart` | `InheritedWidget` exposing controller to registrars |
| Screen registrar | `lib/core/app_bar/app_bar_registrar.dart` | Pushes/pops screen-scoped items via widget lifecycle |
| Screen helper | `lib/core/screen/module_screen_registrar.dart` | Optional AppBar + bottom nav wrapper for module screens |
| Shell widget | `lib/core/app_bar/shell_app_bar.dart` | Renders slots, overflow menu, reserved shell nav controls |
| Shell wiring | `lib/core/navigation/app_shell.dart` | Provides `AppBarScope`, `ShellAppBar`, `ShellNavControls` |

```text
startApp()
  └─ appBarController.setModuleItems(appBarModuleItems)   ← from AppBarSink (optional)

AppShell
  └─ AppBarScope(controller: appBarController)
       ├─ ShellAppBar
       │    ├─ ShellNavControls (back + menu — reserved, not AppBarItem)
       │    └─ items from AppBarController.itemsFor(context)
       └─ body
            └─ Screen
                 └─ AppBarRegistrar(items: [...])  ← screen-scoped items
                      └─ screen content

Optional: use `ModuleScreenRegistrar` to register AppBar + bottom nav together
(see [BOTTOM_NAV_REGISTRATION.md](BOTTOM_NAV_REGISTRATION.md)).
```

## Layout model

`ShellAppBar` lays out toolbar content in fixed slots:

```text
[ Back — reserved ] | LEFT | CENTER | RIGHT | overflow ▼ | [ Menu — reserved ]
```

| Slot | Owner | Notes |
|------|-------|-------|
| Back (left edge) | `AppShell` via `ShellNavControls` | Shown when `Nav.canPop(context)` |
| Left / center / right | Registered `AppBarItem`s | Merged from controller |
| Overflow | `ShellAppBar` | Items that exceed width budget |
| Menu (right edge) | `AppShell` via `ShellNavControls` | Opens navigation drawer |

**Shell nav controls are never an `AppBarItem`.** Back and hamburger are configured through `ShellNavControls` in `AppShell`, keeping navigation controls separate from feature toolbar widgets.

## Item types

All items extend the sealed class **`AppBarItem`** (`register_app_bar_contract.dart`).

### `AppBarTitle`

Screen or module title with optional icon.

```dart
const AppBarTitle(
  text: 'Sample module',
  icon: Icons.widgets_outlined,
)
```

Defaults: `slot = center`, `lifetime = screen`, `priority = 0`.

### `AppBarAction`

Tappable toolbar control (icon-only or icon + label).

```dart
AppBarAction(
  icon: Icons.refresh,
  tooltip: 'Refresh',
  onTap: () => _reload(),
)
```

Defaults: `slot = right`, `lifetime = screen`, `priority = 10`.

### Shared properties

| Property | Purpose |
|----------|---------|
| `slot` | `AppBarSlot.left`, `.center`, or `.right` |
| `lifetime` | `screen`, `permanent`, or `conditional` (see below) |
| `priority` | Lower values stay visible longer when space is tight |
| `visibleWhen` | Optional `BuildContext → bool` predicate; item hidden when false |

## Lifetimes

| Lifetime | Registration mechanism | When active |
|----------|------------------------|-------------|
| **`screen`** | `AppBarRegistrar` wrapping the screen body | While the registrar widget is mounted |
| **`permanent`** | `AppBarSink.addItems` at module startup | Always (merged into every screen) |
| **`conditional`** | `AppBarSink.addItems` + `visibleWhen` predicate | When predicate returns true |

### Rules

1. **`AppBarTitle` defaults to screen lifetime** — use `AppBarRegistrar` on each screen.
2. **`AppBarLifetime.screen` items must use `AppBarRegistrar`** — do not push screen items through `AppBarSink`.
3. **`permanent` / `conditional` items use `AppBarSink`** during `registerApplicationModules`.
4. **Back and menu are not items** — reserved nav chrome only.

### Module-level registration (infrastructure ready)

`AppBarSink` is wired at bootstrap:

```dart
registerApplicationModules(appRouteSink, appDrawerSink, appBarSink);
appBarController.setModuleItems(appBarModuleItems);
```

To add global toolbar actions (e.g. account, sync status):

```dart
void registerMyModuleAppBar(AppBarSink appBar) {
  appBar.addItems([
    AppBarAction(
      icon: Icons.account_circle,
      tooltip: 'Account',
      onTap: () { /* … */ },
      lifetime: AppBarLifetime.permanent,
      slot: AppBarSlot.right,
      priority: 5,
    ),
  ]);
}
```

Call from `module_registry.dart`. No template module uses `AppBarSink` yet; all current titles are screen-scoped.

## Screen-scoped registration — `AppBarRegistrar`

Every screen that needs toolbar content wraps its body:

```dart
class HomeScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return AppBarRegistrar(
      items: const [
        AppBarTitle(text: 'Home', icon: Icons.home),
      ],
      child: Center(
        child: /* screen body */,
      ),
    );
  }
}
```

### Lifecycle

`AppBarRegistrar` is a `StatefulWidget` that talks to `AppBarController` through `AppBarScope`:

| Event | Controller action |
|-------|-------------------|
| `didChangeDependencies` (first time) | `pushScreenScope(this, items)` |
| `didUpdateWidget` (items changed) | `popScreenScope(this)` then `pushScreenScope` |
| `dispose` | `popScreenScope(this)` |

**Navigation pop does not manually pop app bar scopes.** When go_router removes a route, the screen disposes, `AppBarRegistrar.dispose` runs, and the scope is removed automatically. Do not call `popTopScreenScope` from `Nav.pop`.

### `AppBarScope`

`AppBarScope` is an `InheritedWidget` placed by `AppShell` above the route body. Registrars call `AppBarScope.read(context)` — a non-listening read safe to use in `didChangeDependencies`.

## Controller merge logic

`AppBarController.itemsFor(context)` builds the visible toolbar set:

```dart
final merged = <AppBarItem>[
  ..._permanent,                              // module items
  if (_screenStack.isNotEmpty) ..._screenStack.last.items,  // top screen scope
];
return merged
    .where((item) => item.visibleWhen?.call(context) ?? true)
    .toList()
  ..sort((a, b) => a.priority.compareTo(b.priority));
```

- **Module items** (`_permanent`) are always included.
- **Screen items** come from the **top of `_screenStack`** (supports nested registrars if needed).
- Items are filtered by `visibleWhen`, then sorted by ascending `priority`.

The controller extends `ChangeNotifier`. Notifications are deferred to post-frame when fired during build (same pattern as safe listener updates elsewhere in Flutter).

### Reset

Tests and hot restart call:

```dart
resetAppBarRegistry();
resetAppBarController();
```

before module registration, matching the navigation registry reset pattern.

## Responsive overflow

`ShellAppBar` estimates item widths and fits as many as possible within the available budget (toolbar width minus reserved back, menu, and overflow button slots).

| Constant | Value | Purpose |
|----------|-------|---------|
| `_kNavSlotWidth` | 48 | Back and menu buttons |
| `_kOverflowWidth` | 40 | Overflow menu button |
| `_kTitleMaxWidth` | 240 | Title text cap |

Items that do not fit move into a **`PopupMenuButton`** overflow menu. **`AppBarTitle` is always kept visible** if possible (first visible item rule in `_fitItems`).

Priority controls eviction order: lower `priority` values survive width pressure longer.

## Bootstrap integration

From `app_init.dart`:

```dart
resetAppBarRegistry();
resetAppBarController();
registerApplicationModules(appRouteSink, appDrawerSink, appBarSink);
appBarController.setModuleItems(appBarModuleItems);
```

Order matters: reset → register modules (populate sink) → copy sink into controller → build router.

## Adding AppBar content to a new screen

1. Import `app_bar_registrar.dart` and `register_app_bar_contract.dart`.
2. Wrap the screen body in `AppBarRegistrar` with at least one `AppBarTitle`.
3. Add optional `AppBarAction` items in `left`, `center`, or `right` slots.
4. Do **not** add a `Scaffold` or `AppBar` on the screen.
5. For actions that depend on screen state, use a `StatefulWidget` and rebuild registrar items when state changes (`didUpdateWidget` on the registrar handles item list updates).

### Dynamic items example

```dart
AppBarRegistrar(
  items: [
    AppBarTitle(text: 'Editor'),
    AppBarAction(
      icon: Icons.save,
      onTap: _save,
      visibleWhen: (_) => _dirty,
    ),
  ],
  child: /* … */,
)
```

## Adding global (module) toolbar items

1. Create `register<Name>AppBar(AppBarSink appBar)` in the module.
2. Call `appBar.addItems([…])` with `lifetime: AppBarLifetime.permanent` or `conditional`.
3. Wire the call in `module_registry.dart`.
4. Use `visibleWhen` for conditional items (e.g. only when authenticated).

## Testing

Widget tests that exercise navigation also verify app bar title sync (`app_navigation_test.dart`):

- After push, title reflects the new screen.
- After pop, title returns to the previous screen.

Test bootstrap must include:

```dart
resetAppBarRegistry();
resetAppBarController();
registerApplicationModules(…);
appBarController.setModuleItems(appBarModuleItems);
```

## File reference

| File | Purpose |
|------|---------|
| `lib/core/app_bar/contracts/register_app_bar_contract.dart` | Types, slots, lifetimes, `AppBarSink`, `ShellNavControls` |
| `lib/core/app_bar/app_bar_registry.dart` | Module item sink |
| `lib/core/app_bar/app_bar_controller.dart` | Merge logic, `appBarController` singleton |
| `lib/core/app_bar/app_bar_scope.dart` | Inherited controller access |
| `lib/core/app_bar/app_bar_registrar.dart` | Screen-scoped registration widget |
| `lib/core/app_bar/shell_app_bar.dart` | Rendering, overflow, slot layout |
| `lib/core/screen/module_screen_registrar.dart` | AppBar + bottom nav screen wrapper |
| `lib/core/navigation/app_shell.dart` | Wires scope, chrome, nav buttons |

## Common mistakes

| Mistake | Correct approach |
|---------|------------------|
| `Scaffold` + `AppBar` on a screen | Body only; chrome in `AppShell` |
| Screen items via `AppBarSink` | Use `AppBarRegistrar` for `lifetime: screen` |
| Manual app bar pop on `Nav.pop` | Rely on registrar `dispose` |
| Back/menu as `AppBarAction` | Reserved `ShellNavControls` in shell |
| Importing `appBarController` in screens | Use `AppBarRegistrar` + `AppBarScope` |
| Forgetting registrar wrap | Screen shows shell bar with no title/actions |

## Future evolution

| Need | Direction |
|------|-----------|
| Auth-gated global actions | `AppBarSink` + `visibleWhen: (ctx) => isLoggedIn(ctx)` |
| Search in app bar | `AppBarAction` or custom `AppBarTitle` in center slot |
| Per-module overflow policies | Extend `_fitItems` or add slot-specific budgets |
| Test doubles | Inject a custom `AppBarController` via `AppBarScope` in tests |
