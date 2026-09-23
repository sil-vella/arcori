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
import '../../avari/avari_models.dart';
import '../../avari/avari_notifier.dart';
import '../../avari/widgets/inventory_face_chip.dart';
import '../../hub/hub_bottom_nav.dart';

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
        AppBarTitle(text: 'Trove', icon: Icons.inventory_2_outlined),
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
                              ..._troveBody(context, state.profile!),
                          ],
                        ),
                      ),
      ),
    );
  }

  List<Widget> _troveBody(BuildContext context, AvariProfile profile) {
    final bodySmall = context.appTypography.bodySmall.copyWith(
      color: AppChrome.onSurfaceMuted,
    );

    Widget gapSection(Widget section) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: section,
        );

    return [
      gapSection(
        AppChromeSection(
          title: 'Legacy mints',
          goldFrame: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Preserved Legacy — minted closed Arcori out of circulation.',
                style: bodySmall,
              ),
              AppSpacing.gapSm,
              if (profile.trove.isEmpty)
                Text('None yet', style: bodySmall)
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final item in profile.trove)
                      InventoryFaceChip(
                        item: item.asInventoryItem(),
                        captionOverride: item.caption,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      gapSection(
        AppChromeSection(
          title: 'Closed Generations',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gens you raced that closed — mastery at close and how much seeded into the next gen.',
                style: bodySmall,
              ),
              AppSpacing.gapSm,
              if (profile.closedGenerations.isEmpty)
                Text('None yet', style: bodySmall)
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final item in profile.closedGenerations)
                      InventoryFaceChip(
                        item: item.asInventoryItem(),
                        captionOverride: item.caption,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      gapSection(
        AppChromeSection(
          title: 'Preservation Windows',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Designs currently in a Legacy window — mastery / mastery cap.',
                style: bodySmall,
              ),
              AppSpacing.gapSm,
              if (profile.preservationWindows.isEmpty)
                Text('None open', style: bodySmall)
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final item in profile.preservationWindows)
                      InventoryFaceChip(item: item),
                  ],
                ),
            ],
          ),
        ),
      ),
    ];
  }
}
