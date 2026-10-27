import 'package:flutter/material.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../../../core/widgets/app_visuals.dart';
import '../velora_regions.dart';
import '../widgets/velora_image_cover.dart';

/// One Velora land: lore, alliance, standings, and places.
class VeloraRegionScreen extends StatelessWidget {
  const VeloraRegionScreen({required this.regionCode, super.key});

  final String regionCode;

  @override
  Widget build(BuildContext context) {
    final region = veloraRegionByCode(regionCode);
    final body = context.appTypography.bodySmall.copyWith(
      color: AppChrome.onSurface,
      height: 1.35,
    );
    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(
          text: region?.name ?? 'Region',
          iconAsset: AppMarks.velora,
        ),
      ],
      child: AppChromePage(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppChromePage.topClearance(context) + AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: region == null
              ? [
                  Text(
                    'This region is not in the Chronicle.',
                    style: body,
                  ),
                ]
              : [
                  _Hero(region: region),
                  AppSpacing.gapMd,
                  AppChromeSection(
                    title: 'The land',
                    mark: const AppMarkIcon(AppMarks.velora),
                    goldFrame: true,
                    child: Text(region.lore, style: body),
                  ),
                  AppSpacing.gapMd,
                  AppChromeSection(
                    title: 'Alliance',
                    mark: const AppMarkIcon(AppMarks.velora),
                    goldFrame: true,
                    child: Text(region.alliance, style: body),
                  ),
                  AppSpacing.gapMd,
                  AppChromeSection(
                    title: 'Standings',
                    mark: const AppMarkIcon(AppMarks.velora),
                    goldFrame: true,
                    child: region.standings.isEmpty
                        ? Text(
                            'No affinities or hostilities.',
                            style: body,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0;
                                  i < region.standings.length;
                                  i++) ...[
                                if (i > 0) AppSpacing.gapMd,
                                _StandingRow(standing: region.standings[i]),
                              ],
                            ],
                          ),
                  ),
                  if (region.places.isNotEmpty) ...[
                    AppSpacing.gapMd,
                    AppChromeSection(
                      title: 'Places',
                      mark: const AppMarkIcon(AppMarks.velora),
                      goldFrame: true,
                      child: Column(
                        children: [
                          for (var i = 0; i < region.places.length; i++) ...[
                            if (i > 0) AppSpacing.gapSm,
                            _PlaceTile(place: region.places[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.region});

  final VeloraRegion region;

  @override
  Widget build(BuildContext context) {
    return AppCardFrame(
      gold: true,
      background: VeloraImageCover(asset: region.asset),
      child: AspectRatio(
        aspectRatio: 1.35,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region.name,
                  style: context.appTypography.title.copyWith(
                    color: AppChrome.onSurface,
                  ),
                ),
                AppSpacing.gapXxs,
                Text(
                  region.identity,
                  style: context.appTypography.caption.copyWith(
                    color: AppChrome.accentGold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.standing});

  final VeloraStanding standing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${standing.label} · ${veloraRegionName(standing.otherCode)}',
          style: context.appTypography.subtitle.copyWith(
            color: AppChrome.accentGold,
          ),
        ),
        AppSpacing.gapXxs,
        Text(
          standing.reason,
          style: context.appTypography.bodySmall.copyWith(
            color: AppChrome.onSurface,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place});

  final VeloraPlace place;

  @override
  Widget build(BuildContext context) {
    return AppCardFrame(
      gold: true,
      background: VeloraImageCover(asset: place.asset),
      child: AspectRatio(
        aspectRatio: 2.1,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              place.name,
              style: context.appTypography.title.copyWith(
                color: AppChrome.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
