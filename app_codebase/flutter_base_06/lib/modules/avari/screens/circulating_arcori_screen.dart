import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../avari_models.dart';
import '../avari_notifier.dart';
import '../circulating_browse.dart';
import '../widgets/arcori_canister_grid.dart';

/// Player's circulating Arcori, grouped into canisters. Search stays here.
class CirculatingArcoriScreen extends ConsumerStatefulWidget {
  const CirculatingArcoriScreen({super.key});

  @override
  ConsumerState<CirculatingArcoriScreen> createState() =>
      _CirculatingArcoriScreenState();
}

class _CirculatingArcoriScreenState
    extends ConsumerState<CirculatingArcoriScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(avariProfileProvider.notifier).load(force: true);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openCanister(CirculatingCanister canister) {
    Nav.push(
      context,
      AppPaths.avariCanister,
      extra: canister,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(avariProfileProvider);
    final profile = state.profile;

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'My Arcori', iconAsset: AppMarks.arcori),
      ],
      child: AppChromePage(
        child: profile == null
            ? AppChromeCentered(
                child: state.isLoading
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.errorMessage ??
                                'Sign in to view circulating Arcori',
                            style: context.appTypography.body.copyWith(
                              color: state.errorMessage == null
                                  ? AppChrome.onSurface
                                  : context.appColors.red,
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
                onRefresh: () =>
                    ref.read(avariProfileProvider.notifier).load(force: true),
                child: _body(context, profile.access),
              ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<AvariInventoryItem> access,
  ) {
    final searching = _query.trim().isNotEmpty;
    final items = searching
        ? searchCirculating(
            access,
            query: _query,
            sort: CirculatingSort.mastery,
          )
        : filterCirculating(
            access,
            sort: CirculatingSort.mastery,
          );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppChromePage.topClearance(context) + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        TextField(
          controller: _search,
          style: context.appTypography.body.copyWith(
            color: AppChrome.onSurface,
          ),
          decoration: AppChrome.inputDecoration(
            context,
            hintText: 'Search circulating Arcori',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        AppSpacing.gapMd,
        AppChromeSection(
          title: 'Arcori',
          goldFrame: true,
          trailing: Text(
            '${items.length}',
            style: context.appTypography.title.copyWith(
              color: AppChrome.accentGold,
            ),
          ),
          child: ArcoriCanisterGrid(
            canisters: packCirculatingCanisters(items),
            onTap: _openCanister,
          ),
        ),
      ],
    );
  }
}
