import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/theme/theme.dart';
import '../play_models.dart';
import '../play_notifier.dart';
import '../widgets/match_type_select_modal.dart';

/// Play hub — start and end of the match pipeline (stage 1 stays on this route).
class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key});

  Future<void> _onPlayPressed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(matchFlowProvider.notifier);
    notifier.startPlay();
    final type = await showMatchTypeSelectModal(context);
    if (!context.mounted) return;
    if (type == null) {
      notifier.cancelSelection();
      return;
    }
    await notifier.selectType(type);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(matchFlowProvider);
    final canPlay = flow.isIdle;

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Play', icon: Icons.sports_esports_outlined),
      ],
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Play',
                style: context.appTypography.h2,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSm,
              Text(
                flow.isIdle
                    ? 'Press Play to choose a match type.'
                    : flow.phase.label,
                style: context.appTypography.body,
                textAlign: TextAlign.center,
              ),
              if (flow.selectedType != null) ...[
                AppSpacing.gapXs,
                Text(
                  flow.selectedType!.label,
                  style: context.appTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              AppSpacing.gapLg,
              FilledButton(
                onPressed: canPlay ? () => _onPlayPressed(context, ref) : null,
                child: const Text('Play'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
