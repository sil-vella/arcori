import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../../avari/avari_models.dart';
import '../../avari/avari_notifier.dart';
import '../../avari/widgets/inventory_face_chip.dart';
import '../../hub/hub_bottom_nav.dart';
import '../../museum/museum_assets.dart';
import '../../velora/velora_assets.dart';

const String _kTroveRealmCoverAsset =
    'assets/images/velora/maps/birds-eye-with-realm-beyond.png';

/// Personal vault of minted closed Arcori (Legacy) — not circulating access.
class TroveScreen extends ConsumerStatefulWidget {
  const TroveScreen({super.key});

  @override
  ConsumerState<TroveScreen> createState() => _TroveScreenState();
}

class _TroveScreenState extends ConsumerState<TroveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).isAuthenticated) {
        unawaited(ref.read(avariProfileProvider.notifier).load(force: true));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(avariProfileProvider);

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Trove', iconAsset: AppMarks.trove),
      ],
      bottomNavModuleId: hubSinkBottomNavModuleId,
      bottomNavItems: hubSinkBottomNavItems(context),
      child: AppChromePage(
        child: !auth.isAuthenticated && !auth.isBootstrapping
            ? AppChromeCentered(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign in to view your Trove',
                      style: context.appTypography.body.copyWith(
                        color: AppChrome.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapMd,
                    FilledButton(
                      style: context.appButtons.primary.filled,
                      onPressed: () => Nav.push(context, AppPaths.account),
                      child: const Text('Open Account'),
                    ),
                  ],
                ),
              )
            : state.isLoading && state.profile == null
                ? const AppChromeCentered(child: CircularProgressIndicator())
                : state.errorMessage != null && state.profile == null
                    ? AppChromeCentered(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.errorMessage!,
                              style: context.appTypography.body.copyWith(
                                color: context.appColors.red,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            AppSpacing.gapMd,
                            FilledButton(
                              style: context.appButtons.primary.filled,
                              onPressed: () => ref
                                  .read(avariProfileProvider.notifier)
                                  .load(force: true),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(avariProfileProvider.notifier)
                            .load(force: true),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppChromePage.topClearance(context) +
                                AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.xxl,
                          ),
                          children: [
                            if (state.profile != null)
                              ..._troveBody(state.profile!),
                          ],
                        ),
                      ),
      ),
    );
  }

  List<Widget> _troveBody(AvariProfile profile) {
    Widget gapSection(Widget section) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: section,
        );

    return [
      gapSection(
        _TroveCoverCard(
          title: 'Legacy mints',
          mark: const AppMarkIcon(AppMarks.slammers),
          coverAsset: kMuseumHallBackgroundAsset,
          blurb:
              'Preserved Legacy — minted closed slammers out of circulation.',
          count: profile.trove.length,
          countLabel: 'Legacy mints',
          emptyLabel: 'None yet',
          faces: [
            for (final item in profile.trove)
              InventoryFaceChip(
                item: item.asInventoryItem(),
                captionOverride: item.caption,
              ),
          ],
        ),
      ),
      gapSection(
        _TroveCoverCard(
          title: 'Closed Generations',
          mark: const AppMarkIcon(AppMarks.museum),
          coverAsset: kVeloraWorldBackgroundAsset,
          blurb:
              'Gens you raced that closed — mastery at close and how much seeded into the next gen.',
          count: profile.closedGenerations.length,
          countLabel: 'Closed generations',
          emptyLabel: 'None yet',
          faces: [
            for (final item in profile.closedGenerations)
              InventoryFaceChip(
                item: item.asInventoryItem(),
                captionOverride: item.caption,
              ),
          ],
        ),
      ),
      gapSection(
        _TroveCoverCard(
          title: 'Preservation Windows',
          icon: Icons.hourglass_bottom,
          coverAsset: _kTroveRealmCoverAsset,
          blurb: 'Designs currently in a Legacy window — mastery / mastery cap.',
          count: profile.preservationWindows.length,
          countLabel: 'Active windows',
          emptyLabel: 'None open',
          faces: [
            for (final item in profile.preservationWindows)
              InventoryFaceChip(item: item),
          ],
        ),
      ),
    ];
  }
}

/// Vault card: cover fills the frame, copy stays on the left half.
class _TroveCoverCard extends StatelessWidget {
  const _TroveCoverCard({
    required this.title,
    this.icon,
    this.mark,
    required this.coverAsset,
    required this.blurb,
    required this.count,
    required this.countLabel,
    required this.emptyLabel,
    required this.faces,
  });

  final String title;
  final IconData? icon;
  final Widget? mark;
  final String coverAsset;
  final String blurb;
  final int count;
  final String countLabel;
  final String emptyLabel;
  final List<Widget> faces;

  @override
  Widget build(BuildContext context) {
    final bodySmall = context.appTypography.bodySmall.copyWith(
      color: AppChrome.onSurfaceMuted,
    );
    return AppChromeSection(
      title: title,
      icon: icon,
      mark: mark,
      background: _TroveCover(asset: coverAsset),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.5,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(blurb, style: bodySmall),
              AppSpacing.gapSm,
              Text(
                '$count',
                style: context.appTypography.h2.copyWith(
                  color: AppChrome.accentGold,
                ),
              ),
              Text(countLabel, style: bodySmall),
              AppSpacing.gapSm,
              if (faces.isEmpty)
                Text(emptyLabel, style: bodySmall)
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: faces,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TroveCover extends StatelessWidget {
  const _TroveCover({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.surfaceDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          errorBuilder: (_, __, ___) => ColoredBox(color: AppChrome.fieldFill),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                ink.withValues(alpha: 0.94),
                ink.withValues(alpha: 0.72),
                ink.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.28, 0.5],
            ),
          ),
        ),
      ],
    );
  }
}
