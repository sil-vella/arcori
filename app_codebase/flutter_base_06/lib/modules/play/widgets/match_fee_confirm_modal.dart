import 'package:flutter/material.dart';

import '../../../core/modal/modal.dart';
import '../../../core/theme/theme.dart';

/// Confirm online match fee before deduct + matchmaking.
///
/// Returns `true` when the player confirms, `false` on cancel / dismiss.
Future<bool> showMatchFeeConfirmModal(
  BuildContext context, {
  required int feeFragments,
  required String matchLabel,
}) async {
  final result = await AppModal.showCenteredShell<bool>(
    context,
    title: 'Match fee',
    barrierDismissible: false,
    showCloseButton: false,
    child: _MatchFeeConfirmBody(
      feeFragments: feeFragments,
      matchLabel: matchLabel,
    ),
  );
  return result == true;
}

class _MatchFeeConfirmBody extends StatelessWidget {
  const _MatchFeeConfirmBody({
    required this.feeFragments,
    required this.matchLabel,
  });

  final int feeFragments;
  final String matchLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$matchLabel costs $feeFragments Gold Fragments.\n'
          'Confirm to pay and find a match.',
          style: context.appTypography.body,
        ),
        AppSpacing.gapMd,
        FilledButton(
          onPressed: () => AppModal.dismiss(context, true),
          child: Text('Pay $feeFragments Fragments'),
        ),
        AppSpacing.gapSm,
        OutlinedButton(
          onPressed: () => AppModal.dismiss(context, false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
