# arcori — Flutter theme system

Technical guide for colors, typography, spacing, buttons, and `ThemeData` wiring in **flutter_base_06**. All styling tokens live under `lib/core/theme/` and are the **single source of truth (SSOT)** for screens and widgets.

Related docs: [NAVIGATION_SYSTEM.md](NAVIGATION_SYSTEM.md) (shell chrome), [MODAL_SYSTEM.md](MODAL_SYSTEM.md) (overlays), [APPBAR_WIDGET_REGISTRATION.md](APPBAR_WIDGET_REGISTRATION.md), [BOTTOM_NAV_REGISTRATION.md](BOTTOM_NAV_REGISTRATION.md), [STATE_SYSTEM.md](STATE_SYSTEM.md).

## Overview

| Layer | Location | Role |
|-------|----------|------|
| Barrel export | `lib/core/theme/theme.dart` | One import for all theme tokens |
| Colors | `lib/core/theme/app_colors.dart` | Arcori brand palette (logo) — brand, semantic, neutrals |
| Typography | `lib/core/theme/app_typography.dart` | Font sizes, weights, semantic text styles |
| Spacing | `lib/core/theme/app_spacing.dart` | Layout gaps and screen padding |
| Buttons | `lib/core/theme/app_buttons.dart` | Brand + semantic button styles |
| Modals | `lib/core/theme/app_modal_theme.dart` | Scrim, surface, radius, motion |
| Modal shells | `lib/core/modal/` | `AppModal`, centered + full-screen widgets |
| Theme builder | `lib/core/theme/app_theme.dart` | `ThemeData`, `ColorScheme`, context extensions |
| Bootstrap | `lib/app_init.dart` | `MaterialApp.router(theme: AppTheme.light, darkTheme: AppTheme.dark)` |

```text
app_init.dart
  └── MaterialApp.router
        ├── theme: AppTheme.light
        ├── darkTheme: AppTheme.dark
        └── ThemeData
              ├── colorScheme        ← AppColors
              ├── textTheme          ← AppTypography
              ├── *ButtonTheme       ← AppButtonStyles (primary defaults)
              ├── appBarTheme        ← typography + colorScheme
              ├── inputDecorationTheme
              └── extensions
                    ├── AppThemeExtension      (palette shortcuts)
                    ├── AppTypographyExtension (semantic text)
                    ├── AppButtonStylesExtension (button tones)
                    └── AppModalThemeExtension   (modal overlay)
```

## Design principles

1. **One import.** Screens import `package:arcori/core/theme/theme.dart` — not individual token files unless there is a strong reason.
2. **No hardcoded `Colors.*` in modules.** Use `AppColors`, `context.appColors`, or `Theme.of(context).colorScheme`.
3. **Semantic names over raw values.** Prefer `context.appTypography.h2` and `context.appButtons.success.filled` over inline `TextStyle` / `ButtonStyle`.
4. **Material slots still work.** `textTheme.headlineMedium`, `colorScheme.primary`, etc. are mapped from the same tokens — use whichever reads clearer in context.
5. **Brand from logo.** Primary purple, gold, bronze, and green are sampled from `assets/images/branding/logo.jpg`. Each brand/status color has a matching `*Pastel` container and `on*` foreground for contrast.
6. **Platform font by default.** `AppFonts.primary` is `null` (Roboto / SF Pro). Set it when custom fonts are added to `pubspec.yaml`.

## Quick start

```dart
import 'package:arcori/core/theme/theme.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: context.appTypography.h2),
          AppSpacing.gapMd,
          Text('Manage your account.', style: context.appTypography.bodyMuted),
          AppSpacing.gapLg,
          FilledButton(
            style: context.appButtons.primary.filled,
            onPressed: () {},
            child: const Text('Save'),
          ),
          FilledButton(
            style: context.appButtons.error.tonal,
            onPressed: () {},
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}
```

## Context extensions

`AppThemeContext` on `BuildContext` (`app_theme.dart`):

| Getter | Returns |
|--------|---------|
| `appTheme` | Full `ThemeData` |
| `appColorScheme` | `ColorScheme` |
| `appTextTheme` | Material `TextTheme` |
| `appTypography` | Semantic text styles (`h1`, `menu`, `body`, …) |
| `appButtons` | Brand + semantic button styles |
| `appColors` | Pastel palette shortcuts |

## Colors (`AppColors`)

Static `const Color` tokens in `app_colors.dart`.

### Brand (from `assets/images/branding/logo.jpg`)

| Token | Hex | Use |
|-------|-----|-----|
| `primary` / `primaryPastel` | `#6D2885` / `#D6C2DC` | Purple field — main actions and containers |
| `secondary` / `secondaryPastel` | `#FAB537` / `#FDEAC7` | Gold wordmark — supporting actions |
| `tertiary` / `tertiaryPastel` | `#D39F57` / `#F3E4CF` | Emblem bronze — decorative accents |
| `accent` / `accentPastel` | `#6FB52A` / `#D6EAC3` | Logo green — highlights, links, focus |

Filled primary uses light `onPrimary`; text on `primaryPastel` uses `onPrimaryContainer`.

### Semantic status

| Token | Use |
|-------|-----|
| `green` / `greenPastel` | Success / positive |
| `red` / `redPastel` | Error / destructive |
| `amber` / `amberPastel` | Warning / caution |
| `blue` / `bluePastel` | Informational |

### Neutrals

Light: `background`, `surface`, `onSurface`, `onSurfaceMuted`, `outline`, `divider`.

Dark: `backgroundDark`, `surfaceDark`, `onSurfaceDark`, `onSurfaceMutedDark`, `outlineDark`, `dividerDark`.

Each filled token has a matching `on*` color for text/icons on top (e.g. `onPrimary`, `onGreen`).

```dart
Container(color: AppColors.greenPastel)
Text('Saved', style: TextStyle(color: AppColors.green))

// With context
Icon(Icons.check, color: context.appColors.green)
```

## Typography (`AppTypography`)

### Raw tokens

| Class | Contents |
|-------|----------|
| `AppFonts` | `primary` (platform default), `monospace` |
| `AppFontSizes` | `display` 48 → `caption` 11 |
| `AppFontWeights` | `regular`, `medium`, `semiBold`, `bold` |
| `AppLineHeights` | `tight`, `normal`, `relaxed`, `loose` |

### Semantic styles (`context.appTypography`)

| Style | Size | Typical use |
|-------|------|-------------|
| `display` | 48 | Splash / hero |
| `h1` – `h4` | 32 – 20 | Page and section headers |
| `title` / `subtitle` | 18 / 16 | Screen titles |
| `appBarTitle` | 20 | App bar |
| `menu` / `menuSmall` | 16 / 14 | Drawer and nav items |
| `bodyLarge` / `body` / `bodySmall` | 16 / 14 / 12 | Body copy |
| `bodyMuted` | 14 | Secondary text |
| `label` / `caption` | 12 / 11 | Form labels, hints |
| `button` | 14 | Button labels |
| `monospace` / `monospaceSmall` | 12 / 11 | Logs and code |

### Material `TextTheme` mapping

Semantic styles are also assigned to Material 3 slots (`displayLarge`, `headlineMedium`, `bodyMedium`, `labelLarge`, …) so existing `Theme.of(context).textTheme.*` usage stays consistent.

```dart
Text('Home', style: context.appTypography.h2)
Text('Section', style: context.appTextTheme.headlineMedium) // same token
Text(log, style: context.appTypography.monospace)
```

## Spacing (`AppSpacing`)

| Token | Value |
|-------|-------|
| `xxs` – `xxl` | 4, 8, 12, 16, 24, 32, 48 |
| `screenPadding` | `EdgeInsets.all(24)` |
| `screenPaddingCompact` | `EdgeInsets.all(16)` |
| `gapXxs` – `gapLg` | `SizedBox` shorthands |

```dart
Padding(padding: AppSpacing.screenPadding, child: …)
Column(children: [a, AppSpacing.gapMd, b])
```

## Buttons (`AppButtonStyles`)

### Tones

| Tone | Enum | Use |
|------|------|-----|
| Brand | `primary`, `secondary`, `tertiary`, `accent` | Standard actions |
| Semantic | `success`, `error`, `warning`, `info` | Status-driven actions |

### Variants (per tone)

| Variant | Widget | Description |
|---------|--------|-------------|
| `filled` | `FilledButton`, `ElevatedButton` | Solid background |
| `tonal` | `FilledButton.tonal` | Pastel container |
| `outlined` | `OutlinedButton` | Border only |
| `text` | `TextButton` | Minimal / link-style |
| `icon` | `IconButton` | Icon-only |

### Sizes

`context.appButtons.small(style)` and `context.appButtons.large(style)` resize padding, min height, and text.

### Default theme

`AppTheme` sets Material button themes to **primary** styles. Omit `style` on `FilledButton` / `OutlinedButton` / `TextButton` for the default primary look. Pass an explicit `style` for semantic or alternate brand tones.

```dart
// Default primary (from theme)
FilledButton(onPressed: () {}, child: Text('Continue'))

// Semantic
FilledButton(
  style: context.appButtons.success.filled,
  onPressed: () {},
  child: Text('Confirm'),
)

OutlinedButton(
  style: context.appButtons.warning.outlined,
  onPressed: () {},
  child: Text('Review'),
)

FilledButton.tonal(
  style: context.appButtons.error.tonal,
  onPressed: () {},
  child: Text('Discard'),
)

IconButton(
  style: context.appButtons.error.icon,
  onPressed: () {},
  icon: Icon(Icons.delete_outline),
)

// By enum
FilledButton(
  style: context.appButtons.tone(AppButtonTone.info).filled,
  onPressed: () {},
  child: Text('Details'),
)

// Compact
FilledButton(
  style: context.appButtons.small(context.appButtons.primary.filled),
  onPressed: () {},
  child: Text('OK'),
)
```

### Metrics (`AppButtonMetrics`)

Shared layout: `radius` 8, padding small/medium/large, min heights 36 / 44 / 52, icon button sizes 36 / 44 / 52.

## Theme builder (`AppTheme`)

```dart
AppTheme.light          // ThemeData for light mode
AppTheme.dark           // ThemeData for dark mode
AppTheme.colorScheme(Brightness.light)
```

`ThemeData` includes:

- `colorScheme` — light and dark palettes from `AppColors`
- `textTheme` — from `AppTypography.materialTextTheme`
- `scaffoldBackgroundColor`, `dividerColor`
- `appBarTheme` — primary container background, `appBarTitle` text style
- `cardTheme` — 12px radius, outline border, no elevation
- `filledButtonTheme`, `outlinedButtonTheme`, `textButtonTheme`, `iconButtonTheme`, `elevatedButtonTheme`
- `inputDecorationTheme` — label, hint, error styles; 8px radius borders

### Bootstrap wiring

`_RootApp` in `app_init.dart`:

```dart
MaterialApp.router(
  title: 'Arcori',
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  routerConfig: router,
)
```

Intro and auth-bootstrap `MaterialApp` shells do not mount the full theme yet; once `_RootApp` loads, all module screens inherit `AppTheme`.

## Module guidelines

| Do | Don't |
|----|-------|
| `context.appTypography.body` | `TextStyle(fontSize: 14)` |
| `context.appButtons.error.filled` | `FilledButton.styleFrom(backgroundColor: Colors.red)` |
| `AppSpacing.screenPadding` | `EdgeInsets.all(24)` duplicated per screen |
| `AppColors.greenPastel` for status chips | `Colors.green.shade100` |
| `Theme.of(context).colorScheme.error` for inline errors | Hardcoded hex in screens |

Shell chrome (`shell_app_bar.dart`, `app_shell.dart`, `shell_bottom_bar.dart`) should migrate to theme tokens when touched — same rules as module screens.

## Custom fonts

1. Add font files under `assets/fonts/` (or package dependency).
2. Register in `pubspec.yaml` under `flutter: fonts:`.
3. Set `AppFonts.primary` to the family name in `app_typography.dart`.

All semantic text styles pick up the family automatically.

## Adding or changing tokens

1. **New color** — add to `app_colors.dart`, wire into `AppTheme._lightColorScheme` / `_darkColorScheme` if it belongs in `ColorScheme`, and expose on `AppThemeExtension` if screens need a shortcut.
2. **New text style** — add size to `AppFontSizes`, build in `AppTypography._buildStyles`, expose on `AppTypographyExtension`, map to a `TextTheme` slot if appropriate.
3. **New button tone** — extend `AppButtonTone`, add `_tone(...)` call in `AppButtonStyles._build`, expose on `AppButtonStylesExtension`.
4. Run `flutter analyze lib/core/theme/` after changes.

## File reference

```
lib/core/theme/
├── theme.dart           # Barrel export
├── app_colors.dart      # AppColors
├── app_typography.dart  # AppFonts, AppFontSizes, AppTypography, AppTypographyExtension
├── app_spacing.dart     # AppSpacing
├── app_buttons.dart     # AppButtonMetrics, AppButtonTone, AppButtonStyles, AppButtonStylesExtension
└── app_theme.dart       # AppTheme, AppThemeExtension, AppThemeContext
```
