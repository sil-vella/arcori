import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/screen.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/state/auth/auth_state.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_visuals.dart';
import '../velora_assets.dart';
import '../velora_chrome.dart';
import '../velora_notifier.dart';

/// Velora entry: series list (Creation → Civilizations).
class VeloraScreen extends ConsumerStatefulWidget {
  const VeloraScreen({super.key});

  @override
  ConsumerState<VeloraScreen> createState() => _VeloraScreenState();
}

class _VeloraScreenState extends ConsumerState<VeloraScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(veloraProvider.notifier).loadSeries(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final velora = ref.watch(veloraProvider);
    final auth = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (!next.isBootstrapping &&
          next.isAuthenticated &&
          previous?.isAuthenticated != true) {
        ref.read(veloraProvider.notifier).loadSeries(force: true);
      }
    });

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Velora', icon: Icons.public_outlined),
      ],
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(veloraProvider.notifier).loadSeries(force: true),
        child: AppScreenTemplate001(
          backgroundAsset: kVeloraWorldBackgroundAsset,
          scrimOpacity: 0,
          appBarForeground: Colors.white,
          banner: Stack(
            fit: StackFit.expand,
            children: [veloraBannerFade()],
          ),
          slivers: [
            ..._buildContentSlivers(context, auth: auth, velora: velora),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context, {
    required AuthState auth,
    required VeloraState velora,
  }) {
    final bg = veloraContentCanvas();

    if (!auth.isAuthenticated && !auth.isBootstrapping) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(
            color: bg,
            child: Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Text(
                  'Sign in to browse Velora',
                  style: context.appTypography.body.copyWith(
                    color: AppColors.onSurfaceDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    if (velora.isLoading && velora.series.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(
            color: bg,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    if (velora.errorMessage != null && velora.series.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(
            color: bg,
            child: Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      velora.errorMessage!,
                      style: context.appTypography.body.copyWith(
                        color: context.appColors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapMd,
                    FilledButton(
                      onPressed: () => ref
                          .read(veloraProvider.notifier)
                          .loadSeries(force: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }

    if (velora.series.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(
            color: bg,
            child: const AppEmptyState(
              message: 'No series yet',
              icon: Icons.public_outlined,
            ),
          ),
        ),
      ];
    }

    return [
      DecoratedSliver(
        decoration: BoxDecoration(color: bg),
        sliver: SliverPadding(
          padding: AppSpacing.screenPaddingCompact,
          sliver: SliverList.separated(
            itemCount: velora.series.length,
            separatorBuilder: (_, __) => AppSpacing.gapSm,
            itemBuilder: (context, index) {
              final series = velora.series[index];
              return VeloraChromeButton(
                label: series.label,
                textStyle: context.appTypography.title.copyWith(
                  color: AppColors.onSurfaceDark,
                ),
                onTap: () {
                  final q = {
                    'key': series.key,
                    'name': series.label,
                  };
                  Nav.push(
                    context,
                    Uri(
                      path: AppPaths.veloraSeries,
                      queryParameters: q,
                    ).toString(),
                  );
                },
              );
            },
          ),
        ),
      ),
      SliverFillRemaining(
        hasScrollBody: false,
        child: ColoredBox(color: bg),
      ),
    ];
  }
}
