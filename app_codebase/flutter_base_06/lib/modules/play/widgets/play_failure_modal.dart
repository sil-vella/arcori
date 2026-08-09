import 'package:flutter/material.dart';

import '../../../core/modal/modal.dart';
import '../../../core/theme/theme.dart';

/// Centered OK modal when a Play attempt cannot start or fails mid-lobby.
Future<void> showPlayFailureModal(BuildContext context, String message) {
  return AppModal.showCenteredShell<void>(
    context,
    title: 'Could not start match',
    barrierDismissible: false,
    showCloseButton: false,
    child: _PlayFailureBody(message: message),
  );
}

class _PlayFailureBody extends StatelessWidget {
  const _PlayFailureBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: context.appTypography.body),
        AppSpacing.gapMd,
        FilledButton(
          onPressed: () => AppModal.dismiss(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
