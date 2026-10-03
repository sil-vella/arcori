import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/http/media_url.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../avari/avari_notifier.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../../match/widgets/arcori_palette.dart';
import '../../../utils/dev_logger.dart';
import '../kin_api.dart';
import '../kin_backgrounds.dart';
import '../kin_embed_selection.dart';
import '../kin_lottie_embed.dart';
import '../kin_lottie_style.dart';
import '../kin_models.dart';
import '../kin_notifier.dart';
import '../kin_regions.dart';
import '../widgets/kin_lottie_preview.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Min gap between live tint notifier writes while dragging a slider.
/// Preview tints via [LottieDelegates]; this only limits Riverpod rebuild spam.
const Duration _kTintSliderThrottle = Duration(milliseconds: 40);

/// Third wizard step: customize, region, disc color, claim Genesis Kin.
class KinCustomizeScreen extends ConsumerStatefulWidget {
  const KinCustomizeScreen({
    required this.kinSerial,
    this.resumeDraft = false,
    super.key,
  });

  final String kinSerial;

  /// When true, hydrate customize state from the active local draft.
  final bool resumeDraft;

  @override
  ConsumerState<KinCustomizeScreen> createState() => _KinCustomizeScreenState();
}

class _KinCustomizeScreenState extends ConsumerState<KinCustomizeScreen> {
  bool _saving = false;
  bool _savingDraft = false;
  /// Active draft serial already applied for this visit (`resume=1`).
  String? _resumedDraftSerial;
  /// Seed template display name once; do not refill after the user clears it.
  bool _didSeedDefaultName = false;
  late final TextEditingController _nameController;
  final _kinApi = KinApiClient();
  final _http = http.Client();
  String? _templateLottieCache;
  String? _templateLottieCacheUrl;

  /// Embed PNG bytes keyed by [KinEmbed.bakeSource] (skip re-fetch on compose).
  final Map<String, Uint8List> _embedPngCache = {};

  /// Compose identity = embed serials + placement (side/target/p/s); not tint.
  String? _composeSignature;
  Future<String?>? _composeFuture;
  String? _lastComposedJson;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Refresh hot embeds each visit so new host catalog rows appear.
      ref.read(kinCatalogProvider.notifier).load();
      if (widget.resumeDraft) {
        ref.read(kinActiveSaveProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _http.close();
    super.dispose();
  }

  Future<String?> _loadTemplateLottie(KinTemplate template) async {
    final url = resolveMediaUrl(template.lottieUrl);
    if (url.isEmpty) return null;
    if (_templateLottieCache != null && _templateLottieCacheUrl == url) {
      return _templateLottieCache;
    }
    try {
      final res = await _http.get(Uri.parse(url));
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          res.body.isNotEmpty) {
        _templateLottieCache = res.body;
        _templateLottieCacheUrl = url;
        return res.body;
      }
    } catch (_) {}
    return null;
  }

  /// Embed-insert only for live preview; hue/sat/lightDark via [LottieDelegates].
  Future<String?> _composePreviewLottie({
    required KinTemplate template,
    required KinCreationCatalog catalog,
    required List<KinAppliedCustom> applied,
  }) async {
    final jobs = resolveEmbedJobs(
      template: template,
      catalog: catalog,
      applied: applied,
    );
    if (jobs.isEmpty) return null;
    final raw = await _loadTemplateLottie(template);
    if (raw == null || raw.isEmpty) {
      if (LOGGING_SWITCH) {
        customlog('KinCustomize: compose skip — template lottie missing');
      }
      return null;
    }

    final hydrated = <KinEmbedBakeJob>[];
    for (final job in jobs) {
      var bytes = _embedPngCache[job.assetPath];
      if (bytes == null || bytes.isEmpty) {
        bytes = await loadKinEmbedBytes(job.assetPath, httpClient: _http);
        if (bytes != null && bytes.isNotEmpty) {
          _embedPngCache[job.assetPath] = bytes;
        }
      }
      hydrated.add(
        KinEmbedBakeJob(
          embedSerial: job.embedSerial,
          targetLayer: job.targetLayer,
          side: job.side,
          assetPath: job.assetPath,
          p: job.p,
          s: job.s,
          pngBytes: bytes,
        ),
      );
    }

    final body = await bakeKinEmbedsIntoLottie(raw, hydrated, pretty: false);
    if (LOGGING_SWITCH) {
      customlog(
        'KinCustomize: compose ok embeds=${hydrated.length} '
        'bytes=${body.length}',
      );
    }
    return body;
  }

  /// Start compose when selected embeds or their placements change.
  Future<String?> _ensureComposeFuture({
    required KinTemplate template,
    required KinCreationCatalog catalog,
    required List<KinAppliedCustom> applied,
  }) {
    final signature = kinPreviewEmbedSignature(
      template: template,
      catalog: catalog,
      applied: applied,
    );
    if (_composeSignature == signature && _composeFuture != null) {
      return _composeFuture!;
    }
    _composeSignature = signature;
    if (signature.isEmpty) {
      _lastComposedJson = null;
      _composeFuture = Future<String?>.value(null);
      return _composeFuture!;
    }
    final future = _composePreviewLottie(
      template: template,
      catalog: catalog,
      applied: applied,
    );
    _composeFuture = future;
    future.then((json) {
      if (!mounted || _composeSignature != signature) return;
      setState(() {
        _lastComposedJson = json;
      });
    });
    return future;
  }

  Future<void> _saveDraft(KinTemplate template, KinCreationCatalog catalog) async {
    if (_saving || _savingDraft) return;

    final customize = ref.read(kinCustomizeProvider(widget.kinSerial));
    final bgCatalog =
        ref.read(kinBackgroundCatalogProvider).asData?.value ??
            KinBackgroundCatalog.empty;
    final bgScene = customize.resolveBackgroundScene(bgCatalog);

    setState(() => _savingDraft = true);
    final name = customize.chosenName.trim();
    final draft = await ref.read(kinActiveSaveProvider.notifier).save(
          template: template,
          catalog: catalog,
          applied: customize.toAppliedList(),
          displayName: name.isEmpty ? template.displayName : name,
          regionCode: customize.regionCode,
          colorHex: customize.colorHex,
          chosenName: name.isEmpty ? null : name,
          backgroundId: customize.backgroundId,
          backgroundScene: bgScene,
          backgroundFilterMode: customize.backgroundFilterMode,
        );
    if (!mounted) return;
    setState(() => _savingDraft = false);
    if (draft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save draft')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Draft saved (${draft.serial})')),
    );
  }

  Future<void> _claimKin(KinTemplate template, KinCreationCatalog catalog) async {
    if (_saving || _savingDraft) return;
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

    final bgCatalog =
        ref.read(kinBackgroundCatalogProvider).asData?.value ??
            KinBackgroundCatalog.empty;
    final bgScene = customize.resolveBackgroundScene(bgCatalog);

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
          backgroundScene: bgScene,
          backgroundFilterMode: customize.backgroundFilterMode,
        );
    if (!mounted) return;
    if (draft == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save Kin locally')),
      );
      return;
    }

    final String claimLottie;
    try {
      claimLottie = await ref.read(kinSaveStoreProvider).buildBakedLottieJson(
            template: template,
            catalog: catalog,
            applied: customize.toAppliedList(),
            backgroundScene: bgScene,
            // Server BG rebake square-pads once (shifts embeds + character together).
            // Client-side expand before upload desynced catalog embed `p` on HGD.
            expandBackgroundToSquare: false,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not bake Kin face for claim')),
      );
      return;
    }

    final outcome = await _kinApi.claimKin(
      accessToken: token,
      kinSerial: template.serial,
      typeSerial: template.typeSerial,
      chosenName: name,
      regionCode: customize.regionCode!,
      color: customize.colorHex!,
      applied: customize.toAppliedList().map((e) => e.toJson()).toList(),
      background: bgScene.toClaimJson(),
      lottieJson: claimLottie,
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
        child: AppChromePage(
          child: AppChromeCentered(child: CircularProgressIndicator()),
        ),
      );
    }

    if (widget.kinSerial.isEmpty || catalog == null || template == null) {
      return ModuleScreenRegistrar(
        appBarItems: const [
          AppBarTitle(text: 'Customize Kin', icon: Icons.tune),
        ],
        child: AppChromePage(
          child: AppChromeCentered(
            child: Text(
              'Kin not found',
              style: context.appTypography.caption.copyWith(
                color: AppChrome.onSurfaceMuted,
              ),
            ),
          ),
        ),
      );
    }

    final activeSave = ref.watch(kinActiveSaveProvider);
    if (widget.resumeDraft) {
      final draft = activeSave.draft;
      if (!activeSave.isLoading &&
          draft != null &&
          draft.kinSerial == widget.kinSerial &&
          _resumedDraftSerial != draft.serial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_resumedDraftSerial == draft.serial) return;
          ref
              .read(kinCustomizeProvider(widget.kinSerial).notifier)
              .restoreFromDraft(draft);
          final restored =
              ref.read(kinCustomizeProvider(widget.kinSerial)).chosenName;
          _nameController.text = restored;
          _didSeedDefaultName = true;
          setState(() => _resumedDraftSerial = draft.serial);
        });
      }
    }

    final resumePending = widget.resumeDraft &&
        _resumedDraftSerial == null &&
        (activeSave.isLoading ||
            (activeSave.draft?.kinSerial == widget.kinSerial));

    if (!resumePending &&
        !_didSeedDefaultName &&
        _nameController.text.isEmpty &&
        customize.chosenName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didSeedDefaultName) return;
        final notifier =
            ref.read(kinCustomizeProvider(widget.kinSerial).notifier);
        notifier.setChosenName(template.displayName);
        _nameController.text = template.displayName;
        _didSeedDefaultName = true;
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
    final appliedList = customize.toAppliedList();
    final composeSignature = kinPreviewEmbedSignature(
      template: template,
      catalog: catalog,
      applied: appliedList,
    );
    final composeFuture = _ensureComposeFuture(
      template: template,
      catalog: catalog,
      applied: appliedList,
    );

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(text: template.displayName, icon: Icons.tune),
      ],
      child: AppChromePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppChromePage.topClearance(context)),
            Padding(
              padding: AppSpacing.screenPadding.copyWith(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: FutureBuilder<String?>(
                      future: composeFuture,
                      builder: (context, snap) {
                        final composed = snap.data ??
                            (snap.connectionState == ConnectionState.waiting
                                ? _lastComposedJson
                                : snap.data);
                        // Key = template + embed set only (not tint). Stable key
                        // keeps [KinSceneStack] byte cache across level drags.
                        return KinLottiePreview(
                          key: ValueKey(
                            'preview-${template.lottieUrl}|$composeSignature',
                          ),
                          lottieUrl: template.lottieUrl,
                          composedLottieJson: composed,
                          delegates: delegates,
                          scene: bgScene,
                          // Create screen: static frame only (no Lottie tick cost).
                          animate: false,
                        );
                      },
                    ),
                  ),
                  AppSpacing.gapMd,
                  Column(
                    children: [
                      Text(
                        'Arcori',
                        style: context.appTypography.caption.copyWith(
                          color: AppChrome.onSurfaceMuted,
                        ),
                      ),
                      AppSpacing.gapXs,
                      ArcoriCylinder(
                        look: look,
                        size: 112,
                        face: FutureBuilder<String?>(
                          future: composeFuture,
                          builder: (context, snap) {
                            final composed = snap.data ??
                                (snap.connectionState ==
                                        ConnectionState.waiting
                                    ? _lastComposedJson
                                    : snap.data);
                            return KinSceneStack(
                              key: ValueKey(
                                'disc-${template.lottieUrl}|$composeSignature|'
                                '${customize.colorHex}',
                              ),
                              lottieUrl: template.lottieUrl,
                              composedLottieJson: composed,
                              delegates: delegates,
                              scene: bgScene,
                              animate: false,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppChrome.panelBorder),
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                _AdditionsSection(
                  kinSerial: widget.kinSerial,
                  template: template,
                  catalog: catalog,
                  applied: customize.applied,
                ),
                AppSpacing.gapMd,
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
                      color: AppChrome.onSurfaceMuted,
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
                    color: AppChrome.onSurfaceMuted,
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
                                            ? AppChrome.accentGold
                                            : AppChrome.panelBorder,
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
                                        horizontal: AppSpacing.xxs,
                                        vertical: 2,
                                      ),
                                      color: AppColors.backgroundDark
                                          .withValues(alpha: 0.72),
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
                                          color: AppColors.onSurfaceDark,
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
                    color: AppChrome.onSurfaceMuted,
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
                    color: AppChrome.onSurfaceMuted,
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
                  style: context.appTypography.body.copyWith(
                    color: AppChrome.onSurface,
                  ),
                  decoration: AppChrome.inputDecoration(
                    context,
                    hintText: 'Chosen name',
                  ),
                  onChanged: (v) {
                    ref
                        .read(kinCustomizeProvider(widget.kinSerial).notifier)
                        .setChosenName(v);
                  },
                ),
                AppSpacing.gapLg,
                OutlinedButton(
                  onPressed: (_saving || _savingDraft)
                      ? null
                      : () => _saveDraft(template, catalog),
                  child: Text(_savingDraft ? 'Saving draft…' : 'Save draft'),
                ),
                AppSpacing.gapSm,
                FilledButton(
                  onPressed: (_saving || _savingDraft || !customize.canClaim)
                      ? null
                      : () => _claimKin(template, catalog),
                  child: Text(_saving ? 'Claiming…' : 'Claim Kin'),
                ),
              ],
            ),
          ),
        ],
        ),
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

/// Multi-select additions: 3-col image grid; tint sliders for the focused pick.
class _AdditionsSection extends ConsumerStatefulWidget {
  const _AdditionsSection({
    required this.kinSerial,
    required this.template,
    required this.catalog,
    required this.applied,
  });

  final String kinSerial;
  final KinTemplate template;
  final KinCreationCatalog catalog;
  final Map<String, Object?> applied;

  @override
  ConsumerState<_AdditionsSection> createState() => _AdditionsSectionState();
}

class _AdditionsSectionState extends ConsumerState<_AdditionsSection> {
  /// Last tapped selected addition — owns the hue / light-dark sliders.
  String? _focusedEmbedSerial;
  double? _dragHue;
  double? _dragLightDark;
  DateTime _lastTintNotify = DateTime.fromMillisecondsSinceEpoch(0);

  void _pushEmbedTint({
    required String partSerial,
    required String embedSerial,
    double? hue,
    double? lightDark,
    required bool force,
  }) {
    final now = DateTime.now();
    if (!force && now.difference(_lastTintNotify) < _kTintSliderThrottle) {
      return;
    }
    _lastTintNotify = now;
    ref.read(kinCustomizeProvider(widget.kinSerial).notifier).setEmbedTint(
          partSerial: partSerial,
          embedSerial: embedSerial,
          hue: hue,
          lightDark: lightDark,
        );
  }

  @override
  Widget build(BuildContext context) {
    final items = allSelectableEmbeds(
      template: widget.template,
      catalog: widget.catalog,
    );
    if (items.isEmpty) return const SizedBox.shrink();

    final notifier =
        ref.read(kinCustomizeProvider(widget.kinSerial).notifier);

    // Merge selections across parts (character-wide).
    final selected = <String, KinEmbedTint>{};
    for (final item in items) {
      final k = KinCustomizeState.keyFor(
        item.part.serial,
        kKinEmbedImageSerial,
      );
      selected.addAll(parseEmbedSelection(widget.applied[k]));
    }

    // Keep focus on a still-selected embed; otherwise clear.
    final focus = _focusedEmbedSerial;
    final focusValid =
        focus != null && selected.containsKey(focus) ? focus : null;
    if (focus != null && focusValid == null && _focusedEmbedSerial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _focusedEmbedSerial = null);
      });
    }
    final focusedSerial = focusValid;
    ({KinPart part, KinEmbed embed})? focusedItem;
    if (focusedSerial != null) {
      for (final item in items) {
        if (item.embed.serial == focusedSerial) {
          focusedItem = item;
          break;
        }
      }
    }
    final focusedTint = focusedSerial != null
        ? (selected[focusedSerial] ?? const KinEmbedTint())
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Additions', style: context.appTypography.title),
        AppSpacing.gapXxs,
        Text(
          'Tap to toggle. Selected addition shows hue and light/dark below.',
          style: context.appTypography.caption.copyWith(
            color: AppChrome.onSurfaceMuted,
          ),
        ),
        AppSpacing.gapSm,
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final serial = item.embed.serial;
            return _AdditionThumb(
              embed: item.embed,
              selected: selected.containsKey(serial),
              focused: serial == focusedSerial,
              onTap: () {
                final wasOn = selected.containsKey(serial);
                if (wasOn) {
                  if (_focusedEmbedSerial == serial) {
                    notifier.toggleEmbed(
                      partSerial: item.part.serial,
                      embedSerial: serial,
                      selected: false,
                    );
                    setState(() => _focusedEmbedSerial = null);
                  } else {
                    setState(() => _focusedEmbedSerial = serial);
                  }
                } else {
                  notifier.toggleEmbed(
                    partSerial: item.part.serial,
                    embedSerial: serial,
                    selected: true,
                  );
                  setState(() => _focusedEmbedSerial = serial);
                }
              },
            );
          },
        ),
        if (focusedItem != null && focusedTint != null) ...[
          AppSpacing.gapMd,
          Text(
            focusedItem.embed.displayName,
            style: context.appTypography.body,
          ),
          AppSpacing.gapXs,
          Text('Hue', style: context.appTypography.caption),
          Slider(
            value: (_dragHue ?? focusedTint.hue).clamp(-180, 180),
            min: -180,
            max: 180,
            onChanged: (v) {
              setState(() => _dragHue = v);
              _pushEmbedTint(
                partSerial: focusedItem!.part.serial,
                embedSerial: focusedItem.embed.serial,
                hue: v,
                force: false,
              );
            },
            onChangeEnd: (v) {
              setState(() => _dragHue = null);
              _pushEmbedTint(
                partSerial: focusedItem!.part.serial,
                embedSerial: focusedItem.embed.serial,
                hue: v,
                force: true,
              );
            },
          ),
          Text(
            (_dragHue ?? focusedTint.hue).toStringAsFixed(0),
            style: context.appTypography.caption,
          ),
          Text('Light / dark', style: context.appTypography.caption),
          Slider(
            value: (_dragLightDark ?? focusedTint.lightDark).clamp(-1, 1),
            min: -1,
            max: 1,
            onChanged: (v) {
              setState(() => _dragLightDark = v);
              _pushEmbedTint(
                partSerial: focusedItem!.part.serial,
                embedSerial: focusedItem.embed.serial,
                lightDark: v,
                force: false,
              );
            },
            onChangeEnd: (v) {
              setState(() => _dragLightDark = null);
              _pushEmbedTint(
                partSerial: focusedItem!.part.serial,
                embedSerial: focusedItem.embed.serial,
                lightDark: v,
                force: true,
              );
            },
          ),
          Text(
            (_dragLightDark ?? focusedTint.lightDark).toStringAsFixed(2),
            style: context.appTypography.caption,
          ),
        ],
      ],
    );
  }
}

class _AdditionThumb extends StatelessWidget {
  const _AdditionThumb({
    required this.embed,
    required this.selected,
    required this.focused,
    required this.onTap,
  });

  final KinEmbed embed;
  final bool selected;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = focused
        ? AppChrome.accentGold
        : selected
            ? AppChrome.onSurface
            : AppChrome.panelBorder;
    final borderWidth = focused || selected ? 2.0 : 1.0;
    return Material(
      color: AppChrome.panelFill,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: _embedImage(context, embed),
          ),
        ),
      ),
    );
  }

  Widget _embedImage(BuildContext context, KinEmbed embed) {
    final src = embed.bakeSource;
    if (src.isEmpty) {
      return Center(
        child: Text(
          embed.displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.appTypography.caption,
        ),
      );
    }
    final isNetwork = src.startsWith('http://') ||
        src.startsWith('https://') ||
        src.startsWith('/catalog-media/') ||
        src.startsWith('/media/');
    if (isNetwork) {
      final url = resolveMediaUrl(src);
      if (url.isEmpty) {
        return ColoredBox(
          color: AppColors.backgroundDark.withValues(alpha: 0.13),
        );
      }
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: AppColors.backgroundDark.withValues(alpha: 0.13),
        ),
      );
    }
    return Image.asset(
      src,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: AppColors.backgroundDark.withValues(alpha: 0.13),
      ),
    );
  }
}

class _CustomControl extends ConsumerStatefulWidget {
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
  ConsumerState<_CustomControl> createState() => _CustomControlState();
}

class _CustomControlState extends ConsumerState<_CustomControl> {
  double? _dragValue;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  void _pushTint(double v, {required bool force}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastNotify) < _kTintSliderThrottle) {
      return;
    }
    _lastNotify = now;
    ref.read(kinCustomizeProvider(widget.kinSerial).notifier).applyCustom(
          partSerial: widget.part.serial,
          customSerial: widget.custom.serial,
          value: v,
        );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(kinCustomizeProvider(widget.kinSerial).notifier);
    final custom = widget.custom;
    final part = widget.part;
    final catalog = widget.catalog;
    final value = widget.value;
    switch (custom.customType) {
      case KinCustomType.hue:
      case KinCustomType.saturation:
      case KinCustomType.lightDark:
      case KinCustomType.embedHue:
      case KinCustomType.embedLightDark:
        final committed =
            value is num ? value.toDouble() : custom.defaultNumber;
        final current = (_dragValue ?? committed).clamp(custom.min, custom.max);
        final isHue = custom.customType == KinCustomType.hue ||
            custom.customType == KinCustomType.embedHue;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(custom.displayName, style: context.appTypography.body),
            Slider(
              value: current,
              min: custom.min,
              max: custom.max,
              onChanged: (v) {
                setState(() => _dragValue = v);
                _pushTint(v, force: false);
              },
              onChangeEnd: (v) {
                setState(() => _dragValue = null);
                _pushTint(v, force: true);
              },
            ),
            Text(
              current.toStringAsFixed(isHue ? 0 : 2),
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
        // Owned by [_AdditionsSection]; not shown under Parts.
        return const SizedBox.shrink();
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
                  parseCatalogColor(opt.colorHex) ?? AppColors.onSurfaceMuted,
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
