import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Full-screen modal shell. Modules supply [child] and optional footer [actions].
class AppFullScreenModal extends StatelessWidget {
  const AppFullScreenModal({
    required this.child,
    this.title,
    this.actions = const [],
    this.showCloseButton = true,
    this.padding,
    super.key,
  });

  final String? title;
  final Widget child;
  final List<Widget> actions;
  final bool showCloseButton;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final modalTheme = context.appModalTheme;
    final contentPadding = padding ?? AppSpacing.screenPadding;

    return Material(
      color: modalTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || showCloseButton)
              _FullScreenHeader(
                title: title,
                showCloseButton: showCloseButton,
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: contentPadding,
                child: child,
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: contentPadding.copyWith(top: 0),
                child: _ActionsRow(actions: actions),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenHeader extends StatelessWidget {
  const _FullScreenHeader({
    required this.title,
    required this.showCloseButton,
  });

  final String? title;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Text(title!, style: context.appTypography.h4),
          ),
          if (showCloseButton)
            IconButton(
              style: context.appButtons.primary.icon,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: actions,
    );
  }
}
