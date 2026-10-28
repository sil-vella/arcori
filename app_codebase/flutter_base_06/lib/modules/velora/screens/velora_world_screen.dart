import 'package:flutter/material.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../../../core/widgets/app_visuals.dart';
import '../velora_regions.dart';
import '../widgets/velora_image_cover.dart';

/// Short Velora world bible. Lore follows the world bible; preservation
/// follows the current game rules (Arcori close into Velora, slammer Legacy).
class VeloraWorldScreen extends StatelessWidget {
  const VeloraWorldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final body = context.appTypography.bodySmall.copyWith(
      color: AppChrome.onSurface,
      height: 1.35,
    );
    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'The World', iconAsset: AppMarks.velora),
      ],
      child: AppChromePage(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppChromePage.topClearance(context) + AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            for (var i = 0; i < _blocks.length; i++) ...[
              if (i > 0) AppSpacing.gapMd,
              if (_blocks[i].title == 'Regions')
                const _RegionTiles()
              else
                AppChromeSection(
                  title: _blocks[i].title,
                  mark: const AppMarkIcon(AppMarks.velora),
                  goldFrame: true,
                  child: Text(_blocks[i].body, style: body),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorldBlock {
  const _WorldBlock(this.title, this.body);

  final String title;
  final String body;
}

const List<_WorldBlock> _blocks = [
  _WorldBlock(
    'The world',
    'No chronicle records Velora’s beginning. The oldest pages speak of an age before sky, land, or names. Velora is said to have awakened where memories outlive the moment, an echo too meaningful to disappear. Its rivers carry forgotten dreams. Every Arcori holds a fragment of that age. The Museum keeps what is known. The Chronicle keeps what cannot be proven.',
  ),
  _WorldBlock(
    'Avari',
    'Avari walk beside the Arcori. They do not command them, and mastery is progress on a living echo, not ownership. The Chronicle may later name an Avari Master, Generation Creator, or Legacy. The name Avari remains.',
  ),
  _WorldBlock(
    'Gameplay',
    'A match seats three Avari. Each brings one circulating Arcori from their collection. An extra Arcori referred to as the gatherer from the region where the match is taking place is also added to the stack. You play two rounds, and flips add to your mastery of the arcori. Practice is where you learn the slam. It does not change mastery.\n\n'
        'Collecting an Arcori means earning the right to play it, not owning it. A new Avari starts with a handful of Genesis and Pioneers designs, and a starter slammer that never runs out. In an online match, the Arcori you flip gain mastery. That mastery keeps them in your collection for later matches, and it builds the Mastery Value. Rarer designs add more. When a generation closes, it leaves circulation and stays here in Velora, and the next generation enters circulation. Arcori are the world’s history.\n\n'
        'Slammers are how a Legacy reaches your Trove. Each slam adds slammer mastery. You see only the number you gained. Keep playing that slammer. When its mastery reaches the preserve line, you can seal a Legacy. A minted Legacy is kept in your Trove..\n\n'
        'When an Arcori generation is closed, the next generation is created. Slammers follow the same rules, however if a slammer legacy is seealed and minted by an Avari, they become their Legacy Owner and creator of the new generation.',
  ),
  _WorldBlock('Regions', ''),
  _WorldBlock(
    'Still unknown',
    'Who first dreamed Velora. Whether the First Hands still exist, and whether they remember this world. What, if anything, burns beneath Ashdrift’s ash. Scholars notice that every Arcori is a perfect circle. The Chronicle does not confirm why.',
  ),
  _WorldBlock(
    'Preservation',
    'Arcori are the world’s history. While a generation circulates, Avari build mastery on it. When that mastery reaches the generation’s close, it leaves circulation and the next generation is seeded from what was learned. Closed generations stay readable here in Velora.\n\n'
        'Slammers are a player’s own history. Learn one in play. When its mastery reaches the preserve line, a Legacy can be sealed. The slammer you play with stays. Museum and Trove record those personal legacies.',
  ),
];

class _RegionTiles extends StatelessWidget {
  const _RegionTiles();

  @override
  Widget build(BuildContext context) {
    return AppChromeSection(
      title: 'Regions',
      mark: const AppMarkIcon(AppMarks.velora),
      goldFrame: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Five lands are known. Their ties are culture and politics, and they do not bar travel, friendship, or collecting. The Realm Beyond lies past the veil.',
            style: context.appTypography.bodySmall.copyWith(
              color: AppChrome.onSurface,
              height: 1.35,
            ),
          ),
          AppSpacing.gapSm,
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.82,
            ),
            itemCount: veloraRegions.length,
            itemBuilder: (context, index) {
              final region = veloraRegions[index];
              return _RegionTile(region: region);
            },
          ),
        ],
      ),
    );
  }
}

class _RegionTile extends StatelessWidget {
  const _RegionTile({required this.region});

  final VeloraRegion region;

  @override
  Widget build(BuildContext context) {
    return AppCardFrame(
      gold: true,
      background: VeloraImageCover(asset: region.asset),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Nav.push(
                  context,
                  Uri(
                    path: AppPaths.veloraRegion,
                    queryParameters: {'code': region.code},
                  ).toString(),
                );
              },
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTypography.title.copyWith(
                          color: AppChrome.onSurface,
                        ),
                      ),
                      AppSpacing.gapXxs,
                      Text(
                        region.identity,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTypography.caption.copyWith(
                          color: AppChrome.accentGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
