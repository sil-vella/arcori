import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth/auth_providers.dart';
import '../../utils/dev_logger.dart';
import '../match/widgets/arcori_palette.dart';
import 'kin_backgrounds.dart';
import 'kin_catalog_loader.dart';
import 'kin_embed_catalog.dart';
import 'kin_embed_selection.dart';
import 'kin_models.dart';
import 'kin_save_store.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

final kinCatalogLoaderProvider = Provider<KinCatalogLoader>((ref) {
  return KinCatalogLoader();
});

final kinSaveStoreProvider = Provider<KinSaveStore>((ref) {
  return KinSaveStore();
});

class KinCatalogState {
  const KinCatalogState({
    this.catalog,
    this.isLoading = false,
    this.errorMessage,
  });

  final KinCreationCatalog? catalog;
  final bool isLoading;
  final String? errorMessage;

  KinCatalogState copyWith({
    KinCreationCatalog? catalog,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return KinCatalogState(
      catalog: catalog ?? this.catalog,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class KinCatalogNotifier extends StateNotifier<KinCatalogState> {
  KinCatalogNotifier(this._loader, this._ref) : super(const KinCatalogState());

  final KinCatalogLoader _loader;
  final Ref _ref;
  bool _loadedOnce = false;

  /// Bundled assets only — remote embeds always merge onto this snapshot.
  KinCreationCatalog? _bundled;

  Future<void> load({bool force = false}) async {
    if (_loadedOnce && !force && state.catalog != null) {
      // Still refresh hot embeds so new additions appear without app rebuild.
      await refreshRemoteEmbeds();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      _bundled = await _loader.load();
      final catalog = await _mergeRemote(_bundled!);
      _loadedOnce = true;
      state = KinCatalogState(catalog: catalog);
      if (LOGGING_SWITCH) {
        customlog(
          'KinCatalog: loaded types=${catalog.types.length} '
          'kins=${catalog.kins.length} customs=${catalog.customs.length} '
          'embeds=${catalog.embeds.length}',
        );
      }
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('KinCatalog: load failed $e');
      }
      state = KinCatalogState(
        catalog: state.catalog,
        errorMessage: 'Could not load Kin catalog',
      );
    }
  }

  /// Re-fetch `/avari/kin/embeds` and merge onto the bundled catalog.
  Future<void> refreshRemoteEmbeds() async {
    if (_bundled == null) {
      await load(force: true);
      return;
    }
    try {
      final merged = await _mergeRemote(_bundled!);
      state = KinCatalogState(catalog: merged);
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('KinCatalog: refresh embeds failed $e');
      }
    }
  }

  Future<KinCreationCatalog> _mergeRemote(KinCreationCatalog base) async {
    final token = _ref.read(authProvider).accessToken;
    final remote = await fetchKinRemoteEmbeds(accessToken: token);
    return mergeKinRemoteEmbeds(base, remote);
  }
}

final kinCatalogProvider =
    StateNotifierProvider<KinCatalogNotifier, KinCatalogState>((ref) {
  return KinCatalogNotifier(ref.watch(kinCatalogLoaderProvider), ref);
});

class KinActiveSaveState {
  const KinActiveSaveState({
    this.draft,
    this.lottieFile,
    this.isLoading = false,
    this.errorMessage,
  });

  final KinSaveDraft? draft;
  final File? lottieFile;
  final bool isLoading;
  final String? errorMessage;
}

class KinActiveSaveNotifier extends StateNotifier<KinActiveSaveState> {
  KinActiveSaveNotifier(this._store) : super(const KinActiveSaveState());

  final KinSaveStore _store;

  Future<void> refresh() async {
    state = const KinActiveSaveState(isLoading: true);
    try {
      final draft = await _store.readActiveDraft();
      File? file;
      if (draft != null) {
        file = await _store.lottieFileFor(draft);
      }
      state = KinActiveSaveState(draft: draft, lottieFile: file);
      if (LOGGING_SWITCH) {
        customlog(
          'KinActiveSave: draft=${draft?.serial ?? 'none'} '
          'file=${file?.path ?? 'none'}',
        );
      }
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('KinActiveSave: refresh failed $e');
      }
      state = KinActiveSaveState(
        draft: state.draft,
        lottieFile: state.lottieFile,
        errorMessage: 'Could not load local Kin',
      );
    }
  }

  Future<KinSaveDraft?> save({
    required KinTemplate template,
    required KinCreationCatalog catalog,
    required List<KinAppliedCustom> applied,
    String? displayName,
    String? regionCode,
    String? colorHex,
    String? chosenName,
    String? backgroundId,
    KinBackgroundScene? backgroundScene,
    KinBackgroundFilterMode? backgroundFilterMode,
  }) async {
    state = KinActiveSaveState(
      draft: state.draft,
      lottieFile: state.lottieFile,
      isLoading: true,
    );
    try {
      final draft = await _store.save(
        template: template,
        catalog: catalog,
        applied: applied,
        displayName: displayName,
        regionCode: regionCode,
        colorHex: colorHex,
        chosenName: chosenName,
        backgroundId: backgroundId,
        backgroundScene: backgroundScene,
        backgroundFilterMode: backgroundFilterMode,
      );
      final file = await _store.lottieFileFor(draft);
      state = KinActiveSaveState(draft: draft, lottieFile: file);
      if (LOGGING_SWITCH) {
        customlog('KinActiveSave: saved ${draft.serial}');
      }
      return draft;
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('KinActiveSave: save failed $e');
      }
      state = KinActiveSaveState(
        draft: state.draft,
        lottieFile: state.lottieFile,
        errorMessage: 'Could not save Kin',
      );
      return null;
    }
  }
}

final kinActiveSaveProvider =
    StateNotifierProvider<KinActiveSaveNotifier, KinActiveSaveState>((ref) {
  return KinActiveSaveNotifier(ref.watch(kinSaveStoreProvider));
});

/// Ephemeral customize session for one template Kin.
class KinCustomizeState {
  const KinCustomizeState({
    required this.kinSerial,
    this.selectedPartSerial,
    this.applied = const {},
    this.regionCode,
    this.colorHex,
    this.chosenName = '',
    this.backgroundId,
    this.backgroundFilterMode = KinBackgroundFilterMode.theme,
    this.backgroundTheme = kKinBgThemeAbstract,
    this.backgroundStyle,
    this.backgroundColorHex = kKinDefaultBackgroundColorHex,
    this.backgroundColorHexB,
    this.backgroundAngleDegrees = kKinBgAngleDefault,
    this.backgroundSaturation = kKinBgSatDefault,
    this.backgroundLightDark = kKinBgLightDarkDefault,
    this.backgroundTextureId = kKinBgTextureNone,
    this.backgroundTextureIntensity = kKinBgTextureIntensityDefault,
  });

  final String kinSerial;
  final String? selectedPartSerial;

  /// Map key: `$partSerial|$customSerial` → value.
  final Map<String, Object?> applied;
  final String? regionCode;
  final String? colorHex;
  final String chosenName;

  /// Selected image [KinBackgroundOption.id] (image themes) or solid swatch id.
  final String? backgroundId;
  final KinBackgroundFilterMode backgroundFilterMode;
  final String backgroundTheme;
  final String? backgroundStyle;

  /// Solid / gradient color A (hex).
  final String backgroundColorHex;
  /// Gradient color B (hex).
  final String? backgroundColorHexB;
  final double backgroundAngleDegrees;
  final double backgroundSaturation;
  final double backgroundLightDark;
  final String backgroundTextureId;
  final double backgroundTextureIntensity;

  bool get canClaim {
    final name = chosenName.trim();
    return regionCode != null &&
        regionCode!.isNotEmpty &&
        colorHex != null &&
        colorHex!.isNotEmpty &&
        name.isNotEmpty;
  }

  bool get isSolidOrGradientBg {
    final t = backgroundTheme.toUpperCase();
    return t == kKinBgThemeSolid || t == kKinBgThemeGradient;
  }

  KinBackgroundScene resolveBackgroundScene(KinBackgroundCatalog catalog) {
    final theme = backgroundTheme.toUpperCase();
    if (theme == kKinBgThemeSolid) {
      return KinBackgroundScene.solid(
        id: backgroundId ?? 'bg-solid',
        colorHex: backgroundColorHex,
        saturation: backgroundSaturation,
        lightDark: backgroundLightDark,
        textureId: backgroundTextureId,
        textureIntensity: backgroundTextureIntensity,
      );
    }
    if (theme == kKinBgThemeGradient) {
      return KinBackgroundScene.gradient(
        id: backgroundId ?? 'bg-gradient',
        colorHex: backgroundColorHex,
        colorHexB: backgroundColorHexB ?? kArcoriAccentHexes.first,
        angleDegrees: backgroundAngleDegrees,
        saturation: backgroundSaturation,
        lightDark: backgroundLightDark,
        textureId: backgroundTextureId,
        textureIntensity: backgroundTextureIntensity,
      );
    }
    final opt = catalog.byId(backgroundId);
    if (opt != null && opt.isImage) {
      return KinBackgroundScene.image(
        id: opt.id,
        imageUrl: opt.imageUrl!,
        theme: opt.theme,
        style: opt.styleToken,
        fileName: opt.fileName,
      );
    }
    return const KinBackgroundScene.solid(
      id: 'bg-default',
      colorHex: kKinDefaultBackgroundColorHex,
    );
  }

  KinCustomizeState copyWith({
    String? selectedPartSerial,
    Map<String, Object?>? applied,
    String? regionCode,
    String? colorHex,
    String? chosenName,
    String? backgroundId,
    KinBackgroundFilterMode? backgroundFilterMode,
    String? backgroundTheme,
    String? backgroundStyle,
    String? backgroundColorHex,
    String? backgroundColorHexB,
    double? backgroundAngleDegrees,
    double? backgroundSaturation,
    double? backgroundLightDark,
    String? backgroundTextureId,
    double? backgroundTextureIntensity,
    bool clearRegion = false,
    bool clearColor = false,
    bool clearBackground = false,
    bool clearBackgroundStyle = false,
    bool clearBackgroundColorB = false,
  }) {
    return KinCustomizeState(
      kinSerial: kinSerial,
      selectedPartSerial: selectedPartSerial ?? this.selectedPartSerial,
      applied: applied ?? this.applied,
      regionCode: clearRegion ? null : (regionCode ?? this.regionCode),
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      chosenName: chosenName ?? this.chosenName,
      backgroundId:
          clearBackground ? null : (backgroundId ?? this.backgroundId),
      backgroundFilterMode:
          backgroundFilterMode ?? this.backgroundFilterMode,
      backgroundTheme: backgroundTheme ?? this.backgroundTheme,
      backgroundStyle: clearBackgroundStyle
          ? null
          : (backgroundStyle ?? this.backgroundStyle),
      backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
      backgroundColorHexB: clearBackgroundColorB
          ? null
          : (backgroundColorHexB ?? this.backgroundColorHexB),
      backgroundAngleDegrees:
          backgroundAngleDegrees ?? this.backgroundAngleDegrees,
      backgroundSaturation:
          backgroundSaturation ?? this.backgroundSaturation,
      backgroundLightDark: backgroundLightDark ?? this.backgroundLightDark,
      backgroundTextureId: backgroundTextureId ?? this.backgroundTextureId,
      backgroundTextureIntensity:
          backgroundTextureIntensity ?? this.backgroundTextureIntensity,
    );
  }

  static String keyFor(String partSerial, String customSerial) =>
      '$partSerial|$customSerial';

  List<KinAppliedCustom> toAppliedList() {
    final out = <KinAppliedCustom>[];
    for (final entry in applied.entries) {
      final parts = entry.key.split('|');
      if (parts.length != 2) continue;
      out.add(
        KinAppliedCustom(
          partSerial: parts[0],
          customSerial: parts[1],
          value: entry.value,
        ),
      );
    }
    return out;
  }
}

class KinCustomizeNotifier extends StateNotifier<KinCustomizeState> {
  KinCustomizeNotifier({
    required String kinSerial,
    required KinCreationCatalog catalog,
  })  : catalog = catalog,
        super(KinCustomizeState(kinSerial: kinSerial));

  KinCreationCatalog catalog;

  /// Hot-merge embeds without resetting customize session state.
  void updateCatalog(KinCreationCatalog next) {
    catalog = next;
  }

  KinTemplate? get template => catalog.kinBySerial(state.kinSerial);

  void selectPart(String partSerial) {
    state = state.copyWith(selectedPartSerial: partSerial);
  }

  void setRegionCode(String regionCode) {
    state = state.copyWith(regionCode: regionCode);
  }

  void setColorHex(String colorHex) {
    state = state.copyWith(colorHex: colorHex);
  }

  void setBackgroundId(String backgroundId) {
    state = state.copyWith(backgroundId: backgroundId);
  }

  void setBackgroundFilterMode(KinBackgroundFilterMode mode) {
    if (mode == KinBackgroundFilterMode.theme) {
      state = state.copyWith(
        backgroundFilterMode: mode,
        clearBackground: true,
        clearBackgroundStyle: true,
      );
      return;
    }
    state = state.copyWith(
      backgroundFilterMode: mode,
      clearBackground: true,
    );
  }

  void setBackgroundTheme(String theme) {
    final t = theme.trim().toUpperCase();
    if (t.isEmpty) return;
    if (t == kKinBgThemeSolid) {
      state = state.copyWith(
        backgroundFilterMode: KinBackgroundFilterMode.theme,
        backgroundTheme: t,
        backgroundId: 'bg-default',
        backgroundColorHex: kKinDefaultBackgroundColorHex,
        clearBackgroundStyle: true,
        clearBackgroundColorB: true,
      );
      return;
    }
    if (t == kKinBgThemeGradient) {
      state = state.copyWith(
        backgroundFilterMode: KinBackgroundFilterMode.theme,
        backgroundTheme: t,
        backgroundId: 'bg-gradient',
        backgroundColorHex: kKinDefaultBackgroundColorHex,
        backgroundColorHexB: kArcoriAccentHexes.first,
        clearBackgroundStyle: true,
      );
      return;
    }
    state = state.copyWith(
      backgroundFilterMode: KinBackgroundFilterMode.theme,
      backgroundTheme: t,
      clearBackgroundStyle: true,
      clearBackground: true,
    );
  }

  void setBackgroundStyle(String? style) {
    final s = style?.trim().toUpperCase();
    if (s == null || s.isEmpty) {
      state = state.copyWith(clearBackgroundStyle: true, clearBackground: true);
      return;
    }
    state = state.copyWith(
      backgroundFilterMode: KinBackgroundFilterMode.style,
      backgroundStyle: s,
      clearBackground: true,
    );
  }

  void setBackgroundSolidColor(String colorHex, {String? id}) {
    state = state.copyWith(
      backgroundTheme: kKinBgThemeSolid,
      backgroundId: id ?? 'bg-solid',
      backgroundColorHex: colorHex,
      clearBackgroundColorB: true,
    );
  }

  void setBackgroundGradientColorA(String colorHex) {
    state = state.copyWith(
      backgroundTheme: kKinBgThemeGradient,
      backgroundColorHex: colorHex,
    );
  }

  void setBackgroundGradientColorB(String colorHex) {
    state = state.copyWith(
      backgroundTheme: kKinBgThemeGradient,
      backgroundColorHexB: colorHex,
    );
  }

  void setBackgroundAngleDegrees(double degrees) {
    state = state.copyWith(backgroundAngleDegrees: degrees % 360);
  }

  void setBackgroundSaturation(double value) {
    state = state.copyWith(
      backgroundSaturation: value.clamp(kKinBgSatMin, kKinBgSatMax),
    );
  }

  void setBackgroundLightDark(double value) {
    state = state.copyWith(
      backgroundLightDark:
          value.clamp(kKinBgLightDarkMin, kKinBgLightDarkMax),
    );
  }

  void setBackgroundTexture(String textureId) {
    state = state.copyWith(backgroundTextureId: textureId);
  }

  void setBackgroundTextureIntensity(double value) {
    state = state.copyWith(
      backgroundTextureIntensity: value.clamp(
        kKinBgTextureIntensityMin,
        kKinBgTextureIntensityMax,
      ),
    );
  }

  void setChosenName(String name) {
    state = state.copyWith(chosenName: name);
  }

  /// Hydrate customize session from a local [KinSaveDraft] (Continue draft).
  void restoreFromDraft(KinSaveDraft draft) {
    if (draft.kinSerial != state.kinSerial) return;

    final applied = <String, Object?>{};
    for (final a in draft.applied) {
      applied[KinCustomizeState.keyFor(a.partSerial, a.customSerial)] =
          a.value;
    }

    final name = (draft.chosenName ?? draft.displayName).trim();
    var next = KinCustomizeState(
      kinSerial: state.kinSerial,
      applied: applied,
      regionCode: draft.regionCode,
      colorHex: draft.colorHex,
      chosenName: name,
      backgroundId: draft.backgroundId,
    );

    final filterRaw = (draft.backgroundFilterMode ?? '').trim().toLowerCase();
    if (filterRaw == KinBackgroundFilterMode.style.name) {
      next = next.copyWith(
        backgroundFilterMode: KinBackgroundFilterMode.style,
      );
    }

    final bgJson = draft.background;
    if (bgJson != null && bgJson.isNotEmpty) {
      final scene = KinBackgroundScene.fromClaimJson(bgJson);
      final theme = scene.theme.toUpperCase();
      if (scene.isImage) {
        next = next.copyWith(
          backgroundId: scene.id,
          backgroundTheme: theme.isEmpty ? kKinBgThemeAbstract : theme,
          backgroundStyle: scene.style,
          clearBackgroundStyle: scene.style == null || scene.style!.isEmpty,
        );
      } else if (scene.isGradient) {
        next = next.copyWith(
          backgroundId: scene.id,
          backgroundTheme: kKinBgThemeGradient,
          backgroundColorHex: scene.colorHex ?? kKinDefaultBackgroundColorHex,
          backgroundColorHexB: scene.colorHexB ?? kArcoriAccentHexes.first,
          backgroundAngleDegrees:
              scene.angleDegrees ?? kKinBgAngleDefault,
          backgroundSaturation: scene.saturation,
          backgroundLightDark: scene.lightDark,
          backgroundTextureId: scene.textureId,
          backgroundTextureIntensity: scene.textureIntensity,
          clearBackgroundStyle: true,
        );
      } else if (scene.isSolid) {
        next = next.copyWith(
          backgroundId: scene.id,
          backgroundTheme: kKinBgThemeSolid,
          backgroundColorHex: scene.colorHex ?? kKinDefaultBackgroundColorHex,
          backgroundSaturation: scene.saturation,
          backgroundLightDark: scene.lightDark,
          backgroundTextureId: scene.textureId,
          backgroundTextureIntensity: scene.textureIntensity,
          clearBackgroundStyle: true,
          clearBackgroundColorB: true,
        );
      }
    } else if (draft.backgroundId != null &&
        draft.backgroundId!.trim().isNotEmpty) {
      next = next.copyWith(backgroundId: draft.backgroundId);
    }

    final firstAppliedPart =
        draft.applied.isNotEmpty ? draft.applied.first.partSerial : null;
    final template = this.template;
    final selected = firstAppliedPart ??
        (template != null && template.parts.isNotEmpty
            ? template.parts.first.serial
            : null);
    if (selected != null) {
      next = next.copyWith(selectedPartSerial: selected);
    }

    state = next;
    if (LOGGING_SWITCH) {
      customlog(
        'KinCustomize: restored draft=${draft.serial} '
        'applied=${applied.length} region=${draft.regionCode}',
      );
    }
  }

  /// Applies a custom only if the part allows it. Returns false if ignored.
  bool applyCustom({
    required String partSerial,
    required String customSerial,
    required Object? value,
  }) {
    final template = this.template;
    if (template == null) return false;
    final part = template.partBySerial(partSerial);
    if (part == null) return false;
    if (!part.allowsCustom(customSerial)) {
      if (LOGGING_SWITCH) {
        customlog(
          'KinCustomize: reject custom=$customSerial on part=$partSerial',
        );
      }
      return false;
    }
    final custom = catalog.customBySerial(customSerial);
    if (custom == null) return false;
    if (custom.customType == KinCustomType.embedImage) {
      final selected = parseEmbedSelection(value);
      if (selected.isEmpty) {
        // Empty selection = clear.
        clearCustom(partSerial: partSerial, customSerial: customSerial);
        return true;
      }
      for (final embedSerial in selected.keys) {
        if (!part.allowsEmbed(embedSerial)) {
          if (LOGGING_SWITCH) {
            customlog(
              'KinCustomize: reject embed=$embedSerial on part=$partSerial',
            );
          }
          return false;
        }
        if (part.placementFor(embedSerial) == null) {
          if (LOGGING_SWITCH) {
            customlog(
              'KinCustomize: reject embed=$embedSerial — no embedPlacements '
              'on part=$partSerial',
            );
          }
          return false;
        }
      }
      final next = Map<String, Object?>.from(state.applied);
      next[KinCustomizeState.keyFor(partSerial, customSerial)] =
          encodeEmbedSelection(selected);
      state = state.copyWith(applied: next);
      return true;
    } else if (custom.customType == KinCustomType.swapPart) {
      final embedSerial = value?.toString() ?? '';
      if (embedSerial.isNotEmpty && !part.allowsEmbed(embedSerial)) {
        if (LOGGING_SWITCH) {
          customlog(
            'KinCustomize: reject embed=$embedSerial on part=$partSerial',
          );
        }
        return false;
      }
    }
    final next = Map<String, Object?>.from(state.applied);
    next[KinCustomizeState.keyFor(partSerial, customSerial)] = value;
    state = state.copyWith(applied: next);
    return true;
  }

  void clearCustom({
    required String partSerial,
    required String customSerial,
  }) {
    final next = Map<String, Object?>.from(state.applied);
    next.remove(KinCustomizeState.keyFor(partSerial, customSerial));
    if (customSerial == kKinEmbedImageSerial) {
      next.remove(KinCustomizeState.keyFor(partSerial, kKinEmbedHueSerial));
      next.remove(
        KinCustomizeState.keyFor(partSerial, kKinEmbedLightDarkSerial),
      );
    }
    state = state.copyWith(applied: next);
  }

  /// Toggle one addition on/off for the part that owns it (multi-select).
  bool toggleEmbed({
    required String partSerial,
    required String embedSerial,
    required bool selected,
  }) {
    final template = this.template;
    if (template == null) return false;
    final part = template.partBySerial(partSerial);
    if (part == null || !part.allowsCustom(kKinEmbedImageSerial)) return false;
    if (!part.allowsEmbed(embedSerial) ||
        part.placementFor(embedSerial) == null) {
      return false;
    }
    final key = KinCustomizeState.keyFor(partSerial, kKinEmbedImageSerial);
    final current = parseEmbedSelection(state.applied[key]);
    final nextMap = Map<String, KinEmbedTint>.from(current);
    if (selected) {
      nextMap.putIfAbsent(embedSerial, () => const KinEmbedTint());
    } else {
      nextMap.remove(embedSerial);
    }
    return applyCustom(
      partSerial: partSerial,
      customSerial: kKinEmbedImageSerial,
      value: encodeEmbedSelection(nextMap),
    );
  }

  /// Update hue / lightDark for one selected addition.
  bool setEmbedTint({
    required String partSerial,
    required String embedSerial,
    double? hue,
    double? lightDark,
  }) {
    final key = KinCustomizeState.keyFor(partSerial, kKinEmbedImageSerial);
    final current = parseEmbedSelection(state.applied[key]);
    final existing = current[embedSerial];
    if (existing == null) return false;
    final nextMap = Map<String, KinEmbedTint>.from(current);
    nextMap[embedSerial] = existing.copyWith(hue: hue, lightDark: lightDark);
    return applyCustom(
      partSerial: partSerial,
      customSerial: kKinEmbedImageSerial,
      value: encodeEmbedSelection(nextMap),
    );
  }
}

final kinCustomizeProvider = StateNotifierProvider.autoDispose
    .family<KinCustomizeNotifier, KinCustomizeState, String>((ref, kinSerial) {
  // Rebuild only when catalog first becomes available — not on every hot merge.
  final catalogReady =
      ref.watch(kinCatalogProvider.select((s) => s.catalog != null));
  const empty = KinCreationCatalog(
    customTypes: [],
    customs: [],
    embeds: [],
    types: [],
    kins: [],
  );
  final catalog = catalogReady
      ? (ref.read(kinCatalogProvider).catalog ?? empty)
      : empty;
  final notifier = KinCustomizeNotifier(
    kinSerial: kinSerial,
    catalog: catalog,
  );
  ref.listen<KinCatalogState>(kinCatalogProvider, (_, next) {
    final c = next.catalog;
    if (c != null) {
      notifier.updateCatalog(c);
    }
  });
  return notifier;
});
