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

/// Second wizard step: templates for one Kin type.
class KinListScreen extends ConsumerStatefulWidget {
  const KinListScreen({required this.typeSerial, super.key});

  final String typeSerial;

  @override
  ConsumerState<KinListScreen> createState() => _KinListScreenState();
}

class _KinListScreenState extends ConsumerState<KinListScreen> {
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
    final type = catalog?.typeBySerial(widget.typeSerial);
    final kins = catalog?.kinsForType(widget.typeSerial) ?? const [];

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(
          text: type?.displayName ?? 'Kins',
          icon: Icons.face_retouching_natural_outlined,
        ),
      ],
      child: AppChromePage(
        child: state.isLoading && catalog == null
            ? const AppChromeCentered(child: CircularProgressIndicator())
            : widget.typeSerial.isEmpty
                ? AppChromeCentered(
                    child: Text(
                      'Missing Kin type',
                      style: context.appTypography.body.copyWith(
                        color: AppChrome.onSurfaceMuted,
                      ),
                    ),
                  )
                : kins.isEmpty
                    ? AppChromeCentered(
                        child: Text(
                          'No Kins in this type yet',
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
                        itemCount: kins.length,
                        separatorBuilder: (_, __) => AppSpacing.gapSm,
                        itemBuilder: (context, index) {
                          return _KinTile(kin: kins[index]);
                        },
                      ),
      ),
    );
  }
}

class _KinTile extends StatelessWidget {
  const _KinTile({required this.kin});

  final KinTemplate kin;

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
              path: AppPaths.kinCustomize,
              queryParameters: {'kin': kin.serial},
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
                  kin.displayName,
                  style: context.appTypography.title.copyWith(
                    color: AppChrome.onSurface,
                  ),
                ),
                AppSpacing.gapXxs,
                Text(
                  '${kin.serial} · ${kin.parts.length} parts',
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
