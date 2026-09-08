import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/http/media_url.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../avari/avari_notifier.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../../match/widgets/arcori_palette.dart';
import '../kin_api.dart';
import '../kin_backgrounds.dart';
import '../kin_lottie_style.dart';
import '../kin_models.dart';
import '../kin_notifier.dart';
import '../kin_regions.dart';
import '../widgets/kin_lottie_preview.dart';

/// Third wizard step: customize, region, disc color, claim Genesis Kin.
class KinCustomizeScreen extends ConsumerStatefulWidget {
  const KinCustomizeScreen({required this.kinSerial, super.key});

  final String kinSerial;

  @override
  ConsumerState<KinCustomizeScreen> createState() => _KinCustomizeScreenState();
}

class _KinCustomizeScreenState extends ConsumerState<KinCustomizeScreen> {
  bool _saving = false;
  late final TextEditingController _nameController;
  final _kinApi = KinApiClient();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kinCatalogProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save(KinTemplate template, KinCreationCatalog catalog) async {
    if (_saving) return;
    final customize = ref.read(kinCustomizeProvider(widget.kinSerial));
    if (!customize.canClaim) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a name, region, and Arcori color'),
        ),
      );
      return;
    }

    final auth = ref.read(authProvider);
    final token = auth.accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to claim your Kin')),
      );
      return;
    }

    setState(() => _saving = true);
    final name = customize.chosenName.trim();
    final draft = await ref.read(kinActiveSaveProvider.notifier).save(
          template: template,
          catalog: catalog,
          applied: customize.toAppliedList(),
          displayName: name,
          regionCode: customize.regionCode,
          colorHex: customize.colorHex,
          chosenName: name,
          backgroundId: customize.backgroundId,
        );
    if (!mounted) return;
    if (draft == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save Kin locally')),
      );
      return;
    }

    Map<String, dynamic>? lottieJson;
    final lottieFile = ref.read(kinActiveSaveProvider).lottieFile;
    if (lottieFile != null) {
      try {
        final decoded = jsonDecode(await lottieFile.readAsString());
        if (decoded is Map) {
          lottieJson = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        lottieJson = null;
      }
    }

    final bgCatalog =
        ref.read(kinBackgroundCatalogProvider).asData?.value ??
            KinBackgroundCatalog.empty;
    final bgScene = customize.resolveBackgroundScene(bgCatalog);

    final outcome = await _kinApi.claimKin(
      accessToken: token,
      kinSerial: template.serial,
      typeSerial: template.typeSerial,
      chosenName: name,
      regionCode: customize.regionCode!,
      color: customize.colorHex!,
      applied: customize.toAppliedList().map((e) => e.toJson()).toList(),
      lottie: lottieJson,
      background: bgScene.toClaimJson(),
    );

    if (!mounted) return;
    if (!outcome.isSuccess) {
      setState(() => _saving = false);
      final message = outcome.isNetworkError
          ? 'Network error — try again'
          : (outcome.error?.message ?? 'Could not claim Kin');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    await ref.read(avariProfileProvider.notifier).load(force: true);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Claimed ${outcome.data!.chosenName}')),
    );
    Nav.go(context, AppPaths.avari);
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(kinCatalogProvider);
    final catalog = catalogState.catalog;
    final template = catalog?.kinBySerial(widget.kinSerial);
    final customize = ref.watch(kinCustomizeProvider(widget.kinSerial));
    final regionsAsync = ref.watch(kinAssignableRegionsProvider);
    final bgAsync = ref.watch(kinBackgroundCatalogProvider);
    final bgCatalog = bgAsync.asData?.value ?? KinBackgroundCatalog.empty;
    final bgScene = customize.resolveBackgroundScene(bgCatalog);
    final bgOptions = bgCatalog.filtered(
      mode: customize.backgroundFilterMode,
      theme: customize.backgroundTheme,
      styleToken: customize.backgroundStyle,
    );
    final selectedBg = bgCatalog.byId(customize.backgroundId) ??
        (bgOptions.isNotEmpty ? bgOptions.first : null);

    if (catalogState.isLoading && catalog == null) {
      return const ModuleScreenRegistrar(
        appBarItems: [
          AppBarTitle(text: 'Customize Kin', icon: Icons.tune),
        ],
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.kinSerial.isEmpty || catalog == null || template == null) {
      return ModuleScreenRegistrar(
        appBarItems: const [
          AppBarTitle(text: 'Customize Kin', icon: Icons.tune),
        ],
        child: Center(
          child: Text(
            'Kin not found',
            style: context.appTypography.body,
          ),
        ),
      );
    }

    if (_nameController.text.isEmpty && customize.chosenName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier =
            ref.read(kinCustomizeProvider(widget.kinSerial).notifier);
        notifier.setChosenName(template.displayName);
        _nameController.text = template.displayName;
      });
    }

    final selected = template.partBySerial(
          customize.selectedPartSerial ?? '',
        ) ??
        (template.parts.isNotEmpty ? template.parts.first : null);

    if (selected != null &&
        customize.selectedPartSerial != selected.serial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(kinCustomizeProvider(widget.kinSerial).notifier)
            .selectPart(selected.serial);
      });
    }

    if (!customize.isSolidOrGradientBg &&
        selectedBg != null &&
        customize.backgroundId != selectedBg.id &&
        bgOptions.any((o) => o.id == selectedBg.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(kinCustomizeProvider(widget.kinSerial).notifier)
            .setBackgroundId(selectedBg.id);
      });
    }

    final allowedCustoms =
        selected == null ? const <KinCustom>[] : catalog.allowedCustomsFor(selected);

    final styles = resolveLayerStyles(
      template: template,
      catalog: catalog,
      applied: customize.toAppliedList(),
    );
    final delegates = buildKinLottieDelegates(styles);
    final discColor = customize.colorHex;
    final look = ArcoriLook(
      designId: template.serial,
      colorHex: discColor,
      imageUrl: null,
    );

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(text: template.displayName, icon: Icons.tune),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AppSpacing.screenPadding.copyWith(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: KinLottiePreview(
                    key: ValueKey(
                      '${customize.applied}|${bgScene.toClaimJson()}',
                    ),
                    lottieUrl: template.lottieUrl,
                    delegates: delegates,
                    scene: bgScene,
                  ),
                ),
                AppSpacing.gapMd,
                Column(
                  children: [
                    Text('Arcori', style: context.appTypography.caption),
                    AppSpacing.gapXs,
                    ArcoriCylinder(
                      look: look,
                      size: 112,
                      face: KinSceneStack(
                        key: ValueKey(
                          'disc-${customize.applied}|${bgScene.toClaimJson()}|${customize.colorHex}',
                        ),
                        lottieUrl: template.lottieUrl,
                        delegates: delegates,
                        scene: bgScene,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: AppSpacing.screenPadding,
              children: [
                Text('Parts', style: context.appTypography.title),
                AppSpacing.gapSm,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final part in template.parts)
                      ChoiceChip(
                        label: Text(part.displayName),
                        selected: selected?.serial == part.serial,
                        onSelected: (_) {
                          ref
                              .read(
                                kinCustomizeProvider(widget.kinSerial).notifier,
                              )
                              .selectPart(part.serial);
                        },
                      ),
                  ],
                ),
                if (selected != null) ...[
                  AppSpacing.gapMd,
                  Text(
                    selected.anatomical == null
                        ? selected.displayName
                        : '${selected.displayName} (${selected.anatomical})',
                    style: context.appTypography.title,
                  ),
                  AppSpacing.gapXxs,
                  Text(
                    selected.styleLayerNames.length <= 1
                        ? 'Layer ${selected.layerName}'
                        : 'Layers ${selected.styleLayerNames.join(', ')}',
                    style: context.appTypography.caption.copyWith(
                      color: context.appColorScheme.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.gapMd,
                  if (allowedCustoms.isEmpty)
                    Text(
                      'No customs for this part',
                      style: context.appTypography.bodyMuted,
                    )
                  else
                    for (final custom in allowedCustoms) ...[
                      _CustomControl(
                        kinSerial: widget.kinSerial,
                        part: selected,
                        custom: custom,
                        catalog: catalog,
                        value: customize.applied[KinCustomizeState.keyFor(
                          selected.serial,
                          custom.serial,
                        )],
                      ),
                      AppSpacing.gapMd,
                    ],
                ],
                AppSpacing.gapMd,
                Text('Background', style: context.appTypography.title),
                AppSpacing.gapXxs,
                Text(
                  'Theme or style for art; solid / gradient with texture',
                  style: context.appTypography.caption.copyWith(
                    color: context.appColorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapSm,
                bgAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text(
                    'Backgrounds unavailable',
                    style: context.appTypography.bodyMuted,
                  ),
                  data: (catalog) {
                    final filterMode = customize.backgroundFilterMode;
                    final themes = catalog.filterThemes();
                    final styles = catalog.allStyles();
                    final theme = customize.backgroundTheme.toUpperCase();
                    final isSolid = theme == kKinBgThemeSolid;
                    final isGradient = theme == kKinBgThemeGradient;
                    final isPainted = isSolid || isGradient;
                    if (filterMode == KinBackgroundFilterMode.style &&
                        (customize.backgroundStyle == null ||
                            customize.backgroundStyle!.isEmpty) &&
                        styles.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref
                            .read(
                              kinCustomizeProvider(widget.kinSerial).notifier,
                            )
                            .setBackgroundStyle(styles.first);
                      });
                    }
                    final options = catalog.filtered(
                      mode: filterMode,
                      theme: customize.backgroundTheme,
                      styleToken: customize.backgroundStyle,
                    );
                    final notifier = ref.read(
                      kinCustomizeProvider(widget.kinSerial).notifier,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            ChoiceChip(
                              label: const Text('By theme'),
                              selected:
                                  filterMode == KinBackgroundFilterMode.theme,
                              onSelected: (_) => notifier
                                  .setBackgroundFilterMode(
                                KinBackgroundFilterMode.theme,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('By style'),
                              selected:
                                  filterMode == KinBackgroundFilterMode.style,
                              onSelected: (_) => notifier
                                  .setBackgroundFilterMode(
                                KinBackgroundFilterMode.style,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.gapSm,
                        if (filterMode == KinBackgroundFilterMode.theme)
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final t in themes)
                                ChoiceChip(
                                  label: Text(kinBackgroundThemeLabel(t)),
                                  selected: customize.backgroundTheme == t,
                                  onSelected: (_) =>
                                      notifier.setBackgroundTheme(t),
                                ),
                            ],
                          )
                        else
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final style in styles)
                                ChoiceChip(
                                  label: Text(titleFromKinBgToken(style)),
                                  selected:
                                      customize.backgroundStyle == style,
                                  onSelected: (_) =>
                                      notifier.setBackgroundStyle(style),
                                ),
                            ],
                          ),
                        AppSpacing.gapSm,
                        if (isSolid) ...[
                          Text('Color', style: context.appTypography.body),
                          AppSpacing.gapXs,
                          _SolidSwatchRow(
                            selectedHex: customize.backgroundColorHex,
                            onSelect: (hex, id) =>
                                notifier.setBackgroundSolidColor(hex, id: id),
                          ),
                        ] else if (isGradient) ...[
                          Text('Color A', style: context.appTypography.body),
                          AppSpacing.gapXs,
                          _SolidSwatchRow(
                            selectedHex: customize.backgroundColorHex,
                            onSelect: (hex, _) =>
                                notifier.setBackgroundGradientColorA(hex),
                          ),
                          AppSpacing.gapSm,
                          Text('Color B', style: context.appTypography.body),
                          AppSpacing.gapXs,
                          _SolidSwatchRow(
                            selectedHex: customize.backgroundColorHexB ??
                                kArcoriAccentHexes.first,
                            onSelect: (hex, _) =>
                                notifier.setBackgroundGradientColorB(hex),
                          ),
                          AppSpacing.gapSm,
                          Text(
                            'Angle ${customize.backgroundAngleDegrees.round()}°',
                            style: context.appTypography.body,
                          ),
                          Slider(
                            value: customize.backgroundAngleDegrees
                                .clamp(0, 359),
                            min: 0,
                            max: 359,
                            onChanged: notifier.setBackgroundAngleDegrees,
                          ),
                        ] else if (options.isEmpty)
                          Text(
                            filterMode == KinBackgroundFilterMode.style &&
                                    (customize.backgroundStyle == null ||
                                        customize.backgroundStyle!.isEmpty)
                                ? 'Pick a style'
                                : catalog.images.isEmpty
                                    ? 'No backgrounds from server yet'
                                    : 'No backgrounds for this filter',
                            style: context.appTypography.bodyMuted,
                          )
                        else
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: options.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: AppSpacing.xs),
                              itemBuilder: (context, index) {
                                final opt = options[index];
                                final selected =
                                    customize.backgroundId == opt.id ||
                                        (customize.backgroundId == null &&
                                            index == 0);
                                final thumbUrl =
                                    resolveMediaUrl(opt.imageUrl);
                                return InkWell(
                                  onTap: () =>
                                      notifier.setBackgroundId(opt.id),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.sm,
                                  ),
                                  child: Container(
                                    width: 88,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.sm,
                                      ),
                                      border: Border.all(
                                        color: selected
                                            ? context.appColorScheme.primary
                                            : context.appColorScheme
                                                .outlineVariant,
                                        width: selected ? 2 : 1,
                                      ),
                                      image: opt.isImage &&
                                              thumbUrl.isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(thumbUrl),
                                              fit: BoxFit.cover,
                                              onError: (_, __) {},
                                            )
                                          : null,
                                    ),
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      color: Colors.black54,
                                      child: Text(
                                        filterMode ==
                                                KinBackgroundFilterMode.theme
                                            ? opt.styleLabel
                                            : titleFromKinBgToken(opt.theme),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: context.appTypography.caption
                                            .copyWith(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (isPainted) ...[
                          AppSpacing.gapMd,
                          Text(
                            'Saturation ${customize.backgroundSaturation.toStringAsFixed(2)}',
                            style: context.appTypography.body,
                          ),
                          Slider(
                            value: customize.backgroundSaturation
                                .clamp(kKinBgSatMin, kKinBgSatMax),
                            min: kKinBgSatMin,
                            max: kKinBgSatMax,
                            onChanged: notifier.setBackgroundSaturation,
                          ),
                          Text(
                            'Light / dark ${customize.backgroundLightDark.toStringAsFixed(2)}',
                            style: context.appTypography.body,
                          ),
                          Slider(
                            value: customize.backgroundLightDark.clamp(
                              kKinBgLightDarkMin,
                              kKinBgLightDarkMax,
                            ),
                            min: kKinBgLightDarkMin,
                            max: kKinBgLightDarkMax,
                            onChanged: notifier.setBackgroundLightDark,
                          ),
                          AppSpacing.gapSm,
                          Text('Texture', style: context.appTypography.body),
                          AppSpacing.gapXs,
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final tex in kKinBackgroundTextures)
                                ChoiceChip(
                                  label: Text(
                                    kinBackgroundTextureLabel(tex),
                                  ),
                                  selected:
                                      customize.backgroundTextureId == tex,
                                  onSelected: (_) =>
                                      notifier.setBackgroundTexture(tex),
                                ),
                            ],
                          ),
                          if (customize.backgroundTextureId !=
                              kKinBgTextureNone) ...[
                            AppSpacing.gapSm,
                            Text(
                              'Texture intensity ${customize.backgroundTextureIntensity.toStringAsFixed(2)}',
                              style: context.appTypography.body,
                            ),
                            Slider(
                              value: customize.backgroundTextureIntensity
                                  .clamp(
                                kKinBgTextureIntensityMin,
                                kKinBgTextureIntensityMax,
                              ),
                              min: kKinBgTextureIntensityMin,
                              max: kKinBgTextureIntensityMax,
                              onChanged:
                                  notifier.setBackgroundTextureIntensity,
                            ),
                          ],
                        ],
                      ],
                    );
                  },
                ),
                AppSpacing.gapMd,
                Text('Arcori color', style: context.appTypography.title),
                AppSpacing.gapXxs,
                Text(
                  'Rim and back of the disc',
                  style: context.appTypography.caption.copyWith(
                    color: context.appColorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapSm,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (var i = 0; i < kArcoriAccentPalette.length; i++)
                      ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: kArcoriAccentPalette[i],
                          radius: 8,
                        ),
                        label: Text(kArcoriAccentNames[i]),
                        selected: customize.colorHex?.toUpperCase() ==
                            kArcoriAccentHexes[i].toUpperCase(),
                        onSelected: (_) {
                          ref
                              .read(
                                kinCustomizeProvider(widget.kinSerial).notifier,
                              )
                              .setColorHex(kArcoriAccentHexes[i]);
                        },
                      ),
                  ],
                ),
                AppSpacing.gapMd,
                Text('Region', style: context.appTypography.title),
                AppSpacing.gapXxs,
                Text(
                  'Assigned Velora land (Realm Beyond excluded)',
                  style: context.appTypography.caption.copyWith(
                    color: context.appColorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapSm,
                regionsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final r in _fallbackRegions())
                        ChoiceChip(
                          label: Text(r.name),
                          selected: customize.regionCode == r.regionCode,
                          onSelected: (_) {
                            ref
                                .read(
                                  kinCustomizeProvider(widget.kinSerial)
                                      .notifier,
                                )
                                .setRegionCode(r.regionCode);
                          },
                        ),
                    ],
                  ),
                  data: (regions) => Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final r in regions)
                        ChoiceChip(
                          label: Text(r.name),
                          selected: customize.regionCode == r.regionCode,
                          onSelected: (_) {
                            ref
                                .read(
                                  kinCustomizeProvider(widget.kinSerial)
                                      .notifier,
                                )
                                .setRegionCode(r.regionCode);
                          },
                        ),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
                Text('Name', style: context.appTypography.title),
                AppSpacing.gapSm,
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Chosen name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    ref
                        .read(kinCustomizeProvider(widget.kinSerial).notifier)
                        .setChosenName(v);
                  },
                ),
                AppSpacing.gapLg,
                FilledButton(
                  onPressed: (_saving || !customize.canClaim)
                      ? null
                      : () => _save(template, catalog),
                  child: Text(_saving ? 'Claiming…' : 'Save & claim Kin'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<KinRegionOption> _fallbackRegions() => const [
        KinRegionOption(regionCode: 'ASH', name: 'Ashdrift Hill'),
        KinRegionOption(regionCode: 'EVG', name: 'Everlight Grove'),
        KinRegionOption(regionCode: 'LFR', name: 'Little Frost'),
        KinRegionOption(regionCode: 'MWB', name: 'Moonwake Bay'),
        KinRegionOption(regionCode: 'AMB', name: 'Amberwild'),
      ];
}

class _CustomControl extends ConsumerWidget {
  const _CustomControl({
    required this.kinSerial,
    required this.part,
    required this.custom,
    required this.catalog,
    required this.value,
  });

  final String kinSerial;
  final KinPart part;
  final KinCustom custom;
  final KinCreationCatalog catalog;
  final Object? value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(kinCustomizeProvider(kinSerial).notifier);
    switch (custom.customType) {
      case KinCustomType.hue:
      case KinCustomType.saturation:
      case KinCustomType.lightDark:
        final current = value is num
            ? (value as num).toDouble()
            : custom.defaultNumber;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(custom.displayName, style: context.appTypography.body),
            Slider(
              value: current.clamp(custom.min, custom.max),
              min: custom.min,
              max: custom.max,
              onChanged: (v) {
                notifier.applyCustom(
                  partSerial: part.serial,
                  customSerial: custom.serial,
                  value: v,
                );
              },
            ),
            Text(
              current.toStringAsFixed(
                custom.customType == KinCustomType.hue ? 0 : 2,
              ),
              style: context.appTypography.caption,
            ),
          ],
        );
      case KinCustomType.color:
        final colors = custom.allowedColors;
        final selected = value?.toString() ?? custom.defaultColor;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(custom.displayName, style: context.appTypography.body),
            AppSpacing.gapXs,
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final hex in colors)
                  ChoiceChip(
                    label: Text(hex),
                    selected: selected == hex,
                    onSelected: (_) {
                      notifier.applyCustom(
                        partSerial: part.serial,
                        customSerial: custom.serial,
                        value: hex,
                      );
                    },
                  ),
              ],
            ),
          ],
        );
      case KinCustomType.embedImage:
      case KinCustomType.swapPart:
        final embeds = catalog.embedsFor(part);
        final selected = value?.toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(custom.displayName, style: context.appTypography.body),
            AppSpacing.gapXs,
            if (embeds.isEmpty)
              Text(
                'No embeds in pool',
                style: context.appTypography.bodyMuted,
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('None'),
                    selected: selected == null || selected.isEmpty,
                    onSelected: (_) {
                      notifier.clearCustom(
                        partSerial: part.serial,
                        customSerial: custom.serial,
                      );
                    },
                  ),
                  for (final embed in embeds)
                    ChoiceChip(
                      label: Text(embed.displayName),
                      selected: selected == embed.serial,
                      onSelected: (_) {
                        notifier.applyCustom(
                          partSerial: part.serial,
                          customSerial: custom.serial,
                          value: embed.serial,
                        );
                      },
                    ),
                ],
              ),
          ],
        );
    }
  }
}

class _SolidSwatchRow extends StatelessWidget {
  const _SolidSwatchRow({
    required this.selectedHex,
    required this.onSelect,
  });

  final String selectedHex;
  final void Function(String hex, String id) onSelect;

  @override
  Widget build(BuildContext context) {
    final solids = [
      const KinBackgroundOption.color(
        id: 'bg-default',
        displayName: 'Charcoal',
        colorHex: kKinDefaultBackgroundColorHex,
      ),
      for (var i = 0; i < kArcoriAccentHexes.length; i++)
        KinBackgroundOption.color(
          id: 'bg-accent-$i',
          displayName: kArcoriAccentNames[i],
          colorHex: kArcoriAccentHexes[i],
        ),
    ];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final opt in solids)
          ChoiceChip(
            avatar: CircleAvatar(
              backgroundColor:
                  parseCatalogColor(opt.colorHex) ?? Colors.grey,
              radius: 8,
            ),
            label: Text(opt.displayName),
            selected:
                selectedHex.toUpperCase() == opt.colorHex!.toUpperCase(),
            onSelected: (_) => onSelect(opt.colorHex!, opt.id),
          ),
      ],
    );
  }
}
