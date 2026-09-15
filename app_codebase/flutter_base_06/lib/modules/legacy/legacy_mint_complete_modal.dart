import 'package:flutter/material.dart';

import '../../core/modal/modal.dart';
import '../../core/navigation/app_router.dart';
import '../../core/theme/theme.dart';
import 'legacy_api.dart';

Future<void> showLegacyMintCompleteModal(LegacyMintComplete mint) async {
  final ctx = appRootNavigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  final items = mint.preservedItems;
  await AppModal.showCenteredShell<void>(
    ctx,
    title: items.length > 1
        ? 'Legacy Preserved (${items.length})'
        : 'Legacy Preserved',
    barrierDismissible: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          items.length > 1
              ? 'These Arcori entered your Trove as Legacy Owner'
                  '${mint.creatorAttributed ? ' and Generation Creator' : ''}:'
              : 'Generation ${items.first.generationNumber} of '
                  '${items.first.serial} entered your Trove as Legacy Owner'
                  '${mint.creatorAttributed ? ' and Generation Creator' : ''}.',
          style: ctx.appTypography.body,
        ),
        if (items.length > 1) ...[
          AppSpacing.gapMd,
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${item.serial} (gen ${item.generationNumber}'
                '${item.echoGenerationNumber != null ? ' → echo ${item.echoGenerationNumber}' : ''})',
                style: ctx.appTypography.body,
              ),
            ),
        ] else if (items.first.echoGenerationNumber != null) ...[
          AppSpacing.gapSm,
          Text(
            'Echo generation ${items.first.echoGenerationNumber} now circulates.',
            style: ctx.appTypography.bodySmall,
          ),
        ],
        AppSpacing.gapMd,
        FilledButton(
          onPressed: () => AppModal.dismiss(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
