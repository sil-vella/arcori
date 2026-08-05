import 'package:flutter/material.dart';

import '../../../core/modal/modal.dart';
import '../../../core/theme/theme.dart';
import '../play_models.dart';

/// Centered picker for [MatchType]. Returns the chosen type, or null if cancelled.
Future<MatchType?> showMatchTypeSelectModal(BuildContext context) {
  return AppModal.showCenteredShell<MatchType>(
    context,
    title: 'Choose match type',
    child: const _MatchTypeSelectBody(),
  );
}

class _MatchTypeSelectBody extends StatelessWidget {
  const _MatchTypeSelectBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in MatchType.values) ...[
          if (type != MatchType.values.first) AppSpacing.gapSm,
          FilledButton(
            onPressed: () => AppModal.dismiss(context, type),
            child: Text(type.label),
          ),
        ],
      ],
    );
  }
}
