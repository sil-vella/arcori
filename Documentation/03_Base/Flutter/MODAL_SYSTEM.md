# arcori — Flutter modal system

Technical guide for centered and full-screen modal overlays in **flutter_base_06**. Modals are **overlays on the current route** — not go_router destinations. Styling tokens live in [THEME_SYSTEM.md](THEME_SYSTEM.md) (`app_modal_theme.dart`).

Related: [NAVIGATION_SYSTEM.md](NAVIGATION_SYSTEM.md) (`Nav` for routes), [THEME_SYSTEM.md](THEME_SYSTEM.md) (modal tokens), [theme-rule](../../.cursor/rules/theme-rule.mdc) (no inline modal styling in modules).

## Overview

| Layer | Location | Role |
|-------|----------|------|
| Barrel | `lib/core/modal/modal.dart` | One import for modal API + shells |
| Imperative API | `lib/core/modal/app_modal.dart` | `AppModal.showCentered`, `showFullScreen`, `dismiss` |
| Centered shell | `lib/core/modal/app_centered_modal.dart` | Card on dimmed scrim |
| Full-screen shell | `lib/core/modal/app_fullscreen_modal.dart` | Entire viewport overlay |
| Theme tokens | `lib/core/theme/app_modal_theme.dart` | Scrim, surface, radius, motion |

```text
Module screen
  └── AppModal.showCenteredShell(...)
        └── showGeneralDialog (root navigator)
              ├── barrier: AppModalTheme.scrim
              ├── fade + scale (centered) or fade + slide (full screen)
              └── AppCenteredModal / AppFullScreenModal
                    └── module child (content, actions, media)
```

## Design principles

1. **Modals ≠ routes.** Use `AppModal` for ephemeral UI. Use `Nav.push` when the flow belongs in the back stack or drawer.
2. **Imperative API only.** Modules call `AppModal.*` — not raw `showDialog` / `showGeneralDialog`.
3. **Shell provides chrome; modules provide content.** Title, close, scrim, and motion are SSOT. Body, validation, and actions are per module.
4. **Root navigator by default.** `useRootNavigator: true` covers app bar and drawer (same as notification modals in older bases).
5. **Theme first.** Scrim opacity, surface, radius, and padding come from `lib/core/theme/`. No per-screen barrier colors.

## Modal types

| Type | API | Use |
|------|-----|-----|
| **Centered** | `AppModal.showCentered` / `showCenteredShell` | Confirmations, forms, pickers, promos |
| **Full screen** | `AppModal.showFullScreen` / `showFullScreenShell` | Wizards, media viewers, multi-step flows |

| Shell widget | When |
|--------------|------|
| `AppCenteredModal` | Standard card: optional title, scrollable body, action row |
| `AppFullScreenModal` | Safe-area full viewport: header, scrollable body, footer actions |

Low-level `showCentered` / `showFullScreen` accept any `builder` for fully custom layouts while keeping barrier and transitions.

## Quick start

```dart
import 'package:arcori/core/modal/modal.dart';
import 'package:arcori/core/theme/theme.dart';

// Centered confirmation
await AppModal.showCenteredShell<void>(
  context,
  title: 'Delete item?',
  child: Text('This cannot be undone.', style: context.appTypography.body),
  actions: [
    TextButton(
      onPressed: () => AppModal.dismiss(context),
      child: const Text('Cancel'),
    ),
    FilledButton(
      style: context.appButtons.error.filled,
      onPressed: () => AppModal.dismiss(context, true),
      child: const Text('Delete'),
    ),
  ],
);

// Full-screen flow
await AppModal.showFullScreenShell<void>(
  context,
  title: 'Create account',
  child: MyModuleWizard(),
);
```

## API reference

### `AppModal.showCentered<T>`

- Dimmed scrim, centered content, fade + scale transition
- `barrierDismissible` default `true`
- `useRootNavigator` default `true`

### `AppModal.showFullScreen<T>`

- Full viewport overlay, fade + slide transition
- `barrierDismissible` default `false` (back still closes via close button)
- Wrap custom content in `SizedBox.expand` or use `showFullScreenShell`

### `AppModal.showCenteredShell` / `showFullScreenShell`

Convenience wrappers around the standard shell widgets.

### `AppModal.dismiss<T>(context, [result])`

Pops the root modal route. Prefer close/actions calling `Navigator.of(context).pop()` inside the dialog context, or `AppModal.dismiss` from the underlying screen.

## Shell widgets

### `AppCenteredModal`

| Parameter | Default | Notes |
|-----------|---------|-------|
| `child` | required | Module body |
| `title` | null | Optional header text |
| `actions` | `[]` | Footer button row (wrap, end-aligned) |
| `showCloseButton` | `true` | Top-right close |
| `padding` | `AppSpacing.screenPaddingCompact` | Body padding |

Max width: `AppModalMetrics.centeredMaxWidth` (400). Max height: 85% of screen.

### `AppFullScreenModal`

Same parameters; uses `AppSpacing.screenPadding` and `context.appTypography.h4` for title.

## Theme tokens (`AppModalTheme`)

| Token | Value / source |
|-------|----------------|
| `scrim` | `onSurface` at 45% (light) / 55% (dark) |
| `surface` | `AppColors.surface` / `surfaceDark` |
| `border` | `AppColors.outline` / `outlineDark` |
| `maxWidth` | 400 |
| `borderRadius` | 12 |
| `transitionDuration` | 250ms |

Access: `context.appModalTheme` (from `AppThemeContext`).

## Modal vs navigation

| Use `AppModal` | Use `Nav.push` / route |
|----------------|------------------------|
| Temporary overlay on current screen | New screen in app structure |
| No URL / drawer change | Drawer highlight, auth redirect |
| Dismiss returns to exact prior state | Back stack should remember |
| Confirm, picker, promo, wizard overlay | Account, WS demo, module pages |

## Module guidelines

| Do | Don't |
|----|-------|
| `AppModal.showCenteredShell` | `showDialog(context, builder: …)` |
| `context.appTypography` / `context.appButtons` in modal body | Inline `TextStyle` / `ButtonStyle.styleFrom` |
| `AppModal.dismiss` or `Navigator.pop` in actions | `Nav.pop` (go_router stack) |
| Custom `builder` only when shells are too rigid | Duplicate scrim/barrier per module |

## File reference

```
lib/core/modal/
├── modal.dart
├── app_modal.dart
├── app_centered_modal.dart
└── app_fullscreen_modal.dart

lib/core/theme/
└── app_modal_theme.dart
```

## Tests

`test/core/modal/app_modal_test.dart` — centered and full-screen show/dismiss.
