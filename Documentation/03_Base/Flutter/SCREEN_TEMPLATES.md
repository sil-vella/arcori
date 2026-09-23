# Screen layout templates

Reusable body layouts under `lib/core/screen/`. Screens stay body-only; [AppShell](NAVIGATION_SYSTEM.md) still owns the Scaffold. Use with [ModuleScreenRegistrar](APPBAR_WIDGET_REGISTRATION.md).

```dart
import 'package:arcori/core/screen/screen.dart';
```

## Templates

| Id | Widget | Layout |
|----|--------|--------|
| **001** | `AppScreenTemplate001` | Full-bleed top banner / mural under transparent AppBar; content starts at a fraction below the AppBar (default **40%**) |
| **002** | `AppScreenTemplate002` | Full-bleed arena cover for **match play**; self bottom, 1 opponent top / 2 opponents left+right; centered playfield |

### Template 001 — top banner

Full-screen `CustomScrollView`: a leading **banner slot** (default **40%**) scrolls away with content slivers. Fill the slot with any widget (`banner:`), optionally over a page mural (`backgroundAsset` / `background`).

```dart
return ModuleScreenRegistrar(
  appBarItems: const [
    AppBarTitle(text: 'Museum', icon: Icons.account_balance_outlined),
  ],
  child: AppScreenTemplate001(
    backgroundAsset: 'assets/images/velora/museum/museum_hall_v3.webp',
    banner: MyHeroWidget(), // image, disc, copy, …
    // contentStartFraction: 0.4, // default
    // scrimOpacity: 0.42,        // default
    slivers: [
      SliverToBoxAdapter(child: myHeader),
      SliverList(...),
    ],
  ),
);
```

- Registers `ShellChromeRegistrar(extendBodyBehindAppBar: true)` so the mural sits under the AppBar.
- Metrics: `AppScreenTemplate001Metrics.contentStartFraction` / `scrimOpacity`.
- Pass **slivers** (not a nested `ListView`) so the banner and body share one scroll.
- **Museum:** featured Arcori is chosen randomly by the client from `GET …/museum/banner` → `items`, configured via core `app_ui.json` → `museum.featuredSerials` (mtime hot-reload, no API restart).

### Template 002 — match play

Fullscreen match layout (used inside the match modal, **not** under [ModuleScreenRegistrar]). Arena mural covers the screen (`BoxFit.cover`). Player chrome slots:

- **Self** — bottom-center (required)
- **1 opponent** — top-center
- **2 opponents** — left + right at **25%** from top

```dart
return AppScreenTemplate002(
  arenaLayer: ArenaPovBackdrop(...), // preferred: mural + stack camera
  // or backgroundNetworkUrl: arenaUrl when no POV layer
  stackAreaKey: stackAreaKey,
  self: MatchPlayerChrome(...),
  opponents: [oppLeft, oppRight], // 0–2
  center: aimHitSlot, // aim overlay + lock; stack may live in arenaLayer
  overlay: turnHints, // IgnorePointer on text; only End match hit-tests
);
```

- Metrics: `AppScreenTemplate002Metrics.scrimOpacity` / `playfieldMaxWidth` / `playfieldHeight` / `sideOpponentTopFraction`.
- No `ShellChromeRegistrar` — the match surface is already a fullscreen shell modal.
- Player chrome and hint text use `IgnorePointer` so they never steal aim/touch from the 220px playfield slot.

## Shell chrome

| Piece | Role |
|-------|------|
| `ShellChromeController` | Stack of per-screen flags (`extendBodyBehindAppBar`) |
| `ShellChromeScope` | Inherited on [AppShell](NAVIGATION_SYSTEM.md) |
| `ShellChromeRegistrar` | Push/pop flags for the lifetime of a screen |

Do **not** hardcode routes for `extendBodyBehindAppBar` in the shell — use a template or registrar.

## File reference

```
lib/core/screen/
├── screen.dart                      # Barrel
├── module_screen_registrar.dart     # AppBar + bottom nav
├── shell_chrome_*.dart              # extend-behind-AppBar scope
└── templates/
    ├── app_screen_template_001.dart # Top banner
    └── app_screen_template_002.dart # Match play
```
