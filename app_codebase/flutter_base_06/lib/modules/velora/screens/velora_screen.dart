import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../velora_models.dart';
import '../velora_notifier.dart';

/// Velora entry: theme buttons; designs load only after a theme is opened.
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
      ref.read(veloraProvider.notifier).loadThemes(force: true);
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
        ref.read(veloraProvider.notifier).loadThemes(force: true);
      }
    });

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Velora', icon: Icons.public_outlined),
      ],
      child: !auth.isAuthenticated && !auth.isBootstrapping
          ? Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Text(
                  'Sign in to browse Velora',
                  style: context.appTypography.body,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : velora.isLoading && velora.themes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : velora.errorMessage != null && velora.themes.isEmpty
                  ? Center(
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
                                  .loadThemes(force: true),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : velora.themes.isEmpty
                      ? Center(
                          child: Text(
                            'No themes yet',
                            style: context.appTypography.body,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => ref
                              .read(veloraProvider.notifier)
                              .loadThemes(force: true),
                          child: ListView.separated(
                            padding: AppSpacing.screenPadding,
                            itemCount: velora.themes.length,
                            separatorBuilder: (_, __) => AppSpacing.gapSm,
                            itemBuilder: (context, index) {
                              final theme = velora.themes[index];
                              return _ThemeButton(theme: theme);
                            },
                          ),
                        ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.theme});

  final CatalogThemeEntry theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonal(
        onPressed: () {
          final q = {
            'code': theme.themeCode,
            if (theme.theme.isNotEmpty) 'name': theme.theme,
          };
          Nav.push(
            context,
            Uri(path: AppPaths.veloraTheme, queryParameters: q).toString(),
          );
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(theme.label),
        ),
      ),
    );
  }
}
