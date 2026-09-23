import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../kin_models.dart';
import '../kin_notifier.dart';

/// First wizard step: list Kin types (lineages).
class KinTypesScreen extends ConsumerStatefulWidget {
  const KinTypesScreen({super.key});

  @override
  ConsumerState<KinTypesScreen> createState() => _KinTypesScreenState();
}

class _KinTypesScreenState extends ConsumerState<KinTypesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kinCatalogProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kinCatalogProvider);
    final catalog = state.catalog;

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Kin types', icon: Icons.auto_awesome_outlined),
      ],
      child: AppChromePage(
        child: state.isLoading && catalog == null
            ? const AppChromeCentered(child: CircularProgressIndicator())
            : state.errorMessage != null && catalog == null
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
                              .read(kinCatalogProvider.notifier)
                              .load(force: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : catalog == null || catalog.types.isEmpty
                    ? AppChromeCentered(
                        child: Text(
                          'No Kin types yet',
                          style: context.appTypography.body.copyWith(
                            color: AppChrome.onSurfaceMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppChromePage.topClearance(context) + AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.xxl,
                        ),
                        itemCount: catalog.types.length,
                        separatorBuilder: (_, __) => AppSpacing.gapSm,
                        itemBuilder: (context, index) {
                          final type = catalog.types[index];
                          return _TypeTile(type: type);
                        },
                      ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.type});

  final KinType type;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSurfaces.exhibitRadius);
    return Material(
      color: AppChrome.panelFill,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          Nav.push(
            context,
            Uri(
              path: AppPaths.kinList,
              queryParameters: {'type': type.serial},
            ).toString(),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppChrome.panelBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.displayName,
                  style: context.appTypography.title.copyWith(
                    color: AppChrome.onSurface,
                  ),
                ),
                AppSpacing.gapXxs,
                Text(
                  type.serial,
                  style: context.appTypography.caption.copyWith(
                    color: AppChrome.onSurfaceMuted,
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
