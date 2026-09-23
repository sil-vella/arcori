# UI visual refactor (gallery-first reliquary)

**Status**: In Progress (tokens + hubs + Home/Play chrome + match/modals)  
**Created**: 2026-09-19  
**Last Updated**: 2026-09-23

## Objective

Visual-only restyle of the Flutter app into a gallery-first “reliquary” look: discs stay the hero, chrome uses logo purple/gold/bronze/green, and all new styles land in `lib/core/theme/` before screens. **No game logic, API, route, or copy/IA changes.**

## Implementation Steps

- [x] Phase 1 — Theme tokens (`AppRadii`, `AppSurfaces`, `AppHudThemeExtension`, Cormorant display font, gold primary CTA buttons, spacing/modal metrics)
- [x] Phase 2 — Shared primitives (`AppExhibitCard`, `AppSectionRail`, `AppEmptyState`, `AppHudGlassChip`)
- [x] Phase 3 — Shell + hubs (Play thumb CTA, Avari rails, Museum/Tasks/Velora exhibit chrome, drawer gold avatar ring)
- [x] Phase 4 — Modal bronze frames + `AppSpacing.modalPadding*`
- [x] Phase 5 — Match HUD / aim / power / cylinder chrome on theme tokens
- [x] Phase 6 — Shared `AppChromePage` / `AppChromeSection` on Home + Play; immersive match fullscreen (no title chrome); play/match modals forced dark + gold/bronze button tones
- [ ] Visual smoke: Play → practice match HUD → post-match; Avari; Velora; Museum; Tasks (light + dark)
- [ ] Optional follow-up: Kin texture `Colors.*`, auth avatar `Colors.black38`, remaining demo screens

## Current Progress

Theme SSOT extended; hubs and match HUD restyled. **2026-09-23:** in-match surface uses **Template 002** (`AppScreenTemplate002`) — full-bleed arena cover, self bottom / opponents top or L+R, avatar+username chrome; debug stats removed. Home/Play use **AppChromePage**; match opens immersive fullscreen dark shell; lobby + post-match + invite/slam/fee/loadout modals share dark bronze frames and `appButtons` primary/tertiary tones.

## Next Steps

1. Device/browser visual pass (system light + dark).
2. Close leftover off-theme paints in Kin customize / auth if touching those screens next.

## Files Modified

### Theme / primitives
- `app_codebase/flutter_base_06/lib/core/theme/app_radii.dart` (new)
- `app_codebase/flutter_base_06/lib/core/theme/app_surfaces.dart` (new)
- `app_codebase/flutter_base_06/lib/core/theme/app_colors.dart` (unchanged palette; still SSOT)
- `app_codebase/flutter_base_06/lib/core/theme/app_typography.dart` (display font)
- `app_codebase/flutter_base_06/lib/core/theme/app_spacing.dart`
- `app_codebase/flutter_base_06/lib/core/theme/app_buttons.dart` (primary CTA = gold)
- `app_codebase/flutter_base_06/lib/core/theme/app_modal_theme.dart`
- `app_codebase/flutter_base_06/lib/core/theme/app_theme.dart`
- `app_codebase/flutter_base_06/lib/core/theme/theme.dart`
- `app_codebase/flutter_base_06/lib/core/widgets/app_visuals.dart` (new)
- `app_codebase/flutter_base_06/lib/core/widgets/app_chrome.dart` (new)
- `app_codebase/flutter_base_06/assets/fonts/CormorantGaramond-*.ttf` (new)
- `app_codebase/flutter_base_06/pubspec.yaml` (font registration)
- `Documentation/03_Base/Flutter/THEME_SYSTEM.md`

### Shell / hubs / modals / match chrome
- `lib/core/navigation/app_shell.dart`, `lib/core/app_bar/shell_app_bar.dart`
- `lib/core/modal/app_centered_modal.dart`, `app_fullscreen_modal.dart`
- `lib/modules/home/home_screen.dart` — `AppChromePage` + `AppChromeSection`
- `lib/modules/play/screens/play_screen.dart`, `game_controls_screen.dart`, `slam_control_mode_ui.dart`
- `lib/modules/play/widgets/post_match_modal.dart`, `invite_setup_modal.dart`, `match_type_select_modal.dart`, `practice_loadout_modal.dart`, `match_fee_confirm_modal.dart`, `play_failure_modal.dart`
- `lib/modules/match/widgets/practice_match_surface.dart` — immersive fullscreen + glass hints / tertiary End
- `lib/modules/match/widgets/slam_result_modal.dart`
- `lib/modules/avari/screens/avari_profile_screen.dart`, `avari_drawer.dart`
- `lib/modules/museum/screens/museum_screen.dart`
- `lib/modules/tasks/screens/tasks_screen.dart`
- `lib/modules/velora/screens/velora_screen.dart`
- `lib/modules/special_events/*_picker_modal.dart`
- `lib/modules/match/input/slam_input_capture.dart`
- `lib/modules/match/widgets/arcori_stack_surface.dart`, `arcori_cylinder.dart`, `arcori_palette.dart`, `arcori_look.dart`

## Notes

- **2026-09-23:** Match play layout → `AppScreenTemplate002` + `MatchPlayerChrome`; Home/Play/`AppChrome*`; match + play-flow modals (type/loadout/fee/invite/SE pickers/matchmaking lobby/slam result/post-match) forced `AppTheme.dark` with shared bronze/gold headers + `appButtons`. See [SCREEN_TEMPLATES.md](../03_Base/Flutter/SCREEN_TEMPLATES.md).

- **2026-09-19:** Android launch failed — Cormorant font files missing from disk while still listed in `pubspec.yaml`. Restored as OFL static OTFs (`Regular`/`SemiBold`/`Bold`) under `assets/fonts/`.

- **Button tone remap:** `AppButtonTone.primary` filled = gold (Play/claim); `secondary` = purple; `tertiary` outlined = bronze quiet actions. Material `ColorScheme.primary` remains purple for containers/focus.
- Catalog disc accent hexes in `arcori_palette.dart` stay content identity.
- Kin background texture still uses `Colors.white/black` for procedural noise (visual follow-up).

## Case study

n/a for full write-up — visual system only. Locked decision worth a short Technical note later if desired: display font + surface/HUD extensions as gallery-first SSOT.

## Task Manager

App Dev checklist: **UI visual refactor (gallery-first tokens + hubs + match HUD)** — synced (`ok: true`).
